//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapFactory} from "./IUniswapFactory.sol";
import {UniToken} from "./Rs_UniToken.sol";
import {UQ112x112} from "./UQ112x112.sol";
import {FixedPointMathLib} from "@solady/src/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "@solady/src/utils/SafeTransferLib.sol";

/**
 * Note: Solady's sqrt function uses the Babylonian method for calculating sqrt
 * which ensures the floor is returned, so it rounds down.
 */
contract UniswapPair is UniToken, IERC3156FlashLender, ReentrancyGuard {
    using UQ112x112 for uint224;

    uint256 public constant SWAP_FEES = 30; //in basis points (0.3%)
    uint256 public constant BASE = 10_000;
    uint256 public constant MINIMUM_LIQUIDITY = 10 ** 3;
    uint256 private constant PROTOCOL_FEE = 5;
    bytes32 public constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes("transfer(address,uint256)")));

    address public factory;
    address public token0;
    address public token1;

    //single slot - access via `getReserves`
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private blockTimestampLast;

    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    uint256 public kLast; // reserve0 * reserve1, as of immediately after the most recent liquidity event

    event Mint(address indexed sender, uint256 amount0, uint256 amount1);
    event Burn(address indexed sender, uint256 amount0, uint256 amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);
    event FlashLoan(address indexed receiver, address indexed token, uint256 amount, uint256 fee, bytes data);

    constructor() {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address _token1) external {
        require(msg.sender == factory, "UniswapPair: Not factory");
        token0 = _token0;
        token1 = _token1;
    }

    //****************************************************************************************************
    //**************************************** EXTERNAL FUNCTIONS ****************************************
    //****************************************************************************************************

    // force balances to match reserves
    function skim(address to) external nonReentrant {
        address _token0 = token0; // gas savings
        address _token1 = token1; // gas savings
        SafeTransferLib.safeTransfer(_token0, to, IERC20(_token0).balanceOf(address(this)) - reserve0);
        SafeTransferLib.safeTransfer(_token1, to, IERC20(_token1).balanceOf(address(this)) - reserve1);
    }

    // force reserves to match balances
    function sync() external nonReentrant {
        _update(IERC20(token0).balanceOf(address(this)), IERC20(token1).balanceOf(address(this)), reserve0, reserve1);
    }

    /**
     * @param to Liquidity provider who is burning LP tokens to withdraw tokens
     * @param amount0Min Minimum amount of token0 to receive
     * @param amount1Min Minimum amount of token1 to receive
     * @return amount0 Amount of token0 returned from burning LP tokens
     * @return amount1 Amount of token1 returned from burning LP tokens
     *
     * Note: This implementation assumes users will interact directly with contract and not via router.
     * Amounts of token0 and token1 that the liquidity provider receives depends on the ratio of the LP tokens they
     * burn to the total supply of LP topkens. But totalSupply can change before burn transaction finalized, so
     * slippage protection must be implemented.
     */
    function burn(
        address to,
        uint256 amount0Min,
        uint256 amount1Min
    )
        external
        nonReentrant
        returns (uint256, uint256)
    {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        address _token0 = token0;
        address _token1 = token1;
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        uint256 liquidity = balanceOf(address(this));

        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply(); //must be defined here since totalSupply can update in _mintFee
        uint256 amount0 = (liquidity * balance0) / _totalSupply; //using balances ensures pro-rata distribution
        uint256 amount1 = (liquidity * balance1) / _totalSupply; //using balances ensures pro-rata distribution
        require(amount0 > 0 && amount1 > 0, "UniswapPair: INSUFFICIENT_LIQUIDITY_BURNED");

        //Check for slippage. Calculated amounts should be >= minimum amounts specified for slippage tolerance.
        //This would revert if the total supply changes unfavourably where the amount of tokens received
        //from burning LP tokens ends up being less than the minimum amounts specified.
        require(amount0 >= amount0Min, "UniswapPair: SLIPPAGE_AMOUNT0");
        require(amount1 >= amount1Min, "UniswapPair: SLIPPAGE_AMOUNT1");

        //Ensure that burning LP tokens does not result in `totalSupply` going to zero, to prevent potential
        //first deposit attack, where an attacker can manipulate pool by reducing `totalSupply` to zero, effectively
        //resetting the pool and becoming the first to deposit and set an unreasonable initial price ratio.
        require(_totalSupply - liquidity > 0, "UniswapPair: ZERO_TOTAL_SUPPLY");

        _burn(address(this), liquidity);
        SafeTransferLib.safeTransfer(_token0, to, amount0);
        SafeTransferLib.safeTransfer(_token1, to, amount1);

        balance0 = IERC20(_token0).balanceOf(address(this));
        balance1 = IERC20(_token1).balanceOf(address(this));
        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) {
            kLast = uint256(reserve0) * reserve1; //reserve0 and reserve1 are updated in _update
        }

        emit Burn(msg.sender, amount0, amount1, to);
        return (amount0, amount1);
    }

    /**
     * @param to Recipient of the minted tokens
     * Note: this low-level function should be called from a contract which performs important safety checks
     * Total supply of LP could change at the time, so slippage protection must be implemented.
     *
     * If first liquidity provider, LP tokens minted is the geometric mean of amount0 and amount1, minus MINIMUM_LIQUIDITY.
     * Subtraction is done to prevent inflation attacks: burning shares so no one owns entire supply of LP tokens and can
     * manipulate prices. The burned shares from the first liquidity provider are removed from circulation. By doing so, it
     * prevents a scenario where totalSupply of LP tokens can be disproportionately high relative to actual balance in pool.
     * Since no one owns entire supply of LP tokens, no one can add/remove liquidity and manipulate prices at will as the
     * `MINIMUM_LIQUIDITY` ensures base level of liquidity in the pool.
     *
     * Subsequent liquidity providers are incentivized to add tokens in a ratio close to the current ratio of the pool.
     * The amount of LP tokens minted to these providers is the lower of the two ratios.
     */
    function mint(address to) external nonReentrant returns (uint256) {
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        uint256 balance0 = IERC20(token0).balanceOf(address(this));
        uint256 balance1 = IERC20(token1).balanceOf(address(this));
        //Get amount of tokens sent as part of tx
        uint256 amount0 = balance0 - _reserve0;
        uint256 amount1 = balance1 - _reserve1;
        uint256 liquidity;
        bool feeOn = _mintFee(_reserve0, _reserve1);
        uint256 _totalSupply = totalSupply(); //must be defined here since totalSupply can update in _mintFee
        if (_totalSupply == 0) {
            liquidity = FixedPointMathLib.sqrt(amount0 * amount1) - MINIMUM_LIQUIDITY;
            _mint(address(0), MINIMUM_LIQUIDITY); //permanently lock the first MINIMUM_LIQUIDITY LP tokens
        } else {
            liquidity =
                FixedPointMathLib.min((amount0 * _totalSupply) / _reserve0, (amount1 * _totalSupply) / _reserve1);
        }
        require(liquidity > 0, "UniswapPair: INSUFFICIENT_LIQUIDITY_MINTED");
        _mint(to, liquidity);

        _update(balance0, balance1, _reserve0, _reserve1);
        if (feeOn) {
            kLast = uint256(reserve0) * reserve1; //reserve0 and reserve1 are updated in _update
        }

        emit Mint(msg.sender, amount0, amount1);
        return liquidity;
    }

    /**
     * @param amount0Out Amount of token0 to receive from the swap
     * @param amount1Out Amount of token1 to receive from the swap
     * @param to Recipient of the swap
     *
     * Note: this low-level function should be called from a contract which performs important safety checks
     * Recall that `reserve` is previous balance, and `balance` is current balance.
     * The user/calling contract has to supply a certain amount of one of the tokens to the pair contract (pool),
     * before calling the `swap` function.
     *
     * In balancing X * Y = K, K either remains or increases. If it increases, it increases by an amount that
     * enforces the 0.3% fee. The fee in only applied to incoming tokens from the swap.
     * K new must be >= K prev.
     */
    function swap(uint256 amount0Out, uint256 amount1Out, address to) external nonReentrant {
        require(amount0Out > 0 || amount1Out > 0, "UniswapPair: INSUFFICIENT_OUTPUT_AMOUNT");
        (uint112 _reserve0, uint112 _reserve1,) = getReserves();
        require(amount0Out < _reserve0 && amount1Out < _reserve1, "UniswapPair: INSUFFICIENT_LIQUIDITY");

        address _token0 = token0;
        address _token1 = token1;
        require(to != _token0 && to != _token1, "UniswapPair: INVALID_TO");
        // Optimistically transfer tokens - assumes incoming tokens are transferred to pool
        if (amount0Out > 0) SafeTransferLib.safeTransfer(_token0, to, amount0Out);
        if (amount1Out > 0) SafeTransferLib.safeTransfer(_token1, to, amount1Out);
        // Get current balance of token0 & token1 held by this contract
        uint256 balance0 = IERC20(_token0).balanceOf(address(this));
        uint256 balance1 = IERC20(_token1).balanceOf(address(this));
        // Calculate amount of token0 & token1 sent to the pool by the caller.
        // Either there us a net increase or a net decrease (no change) in the amount of a particular token.
        // If net decrease, then `amountIn` will be 0.
        uint256 amount0In = (balance0 > _reserve0 - amount0Out) ? balance0 - (_reserve0 - amount0Out) : 0;
        uint256 amount1In = (balance1 > _reserve1 - amount1Out) ? balance1 - (_reserve1 - amount1Out) : 0;
        require(amount0In > 0 || amount1In > 0, "UniswapPair: INSUFFICIENT_INPUT_AMOUNT");
        // Adjust balances by multiplying `amountIn` by the swap fee and subtracting from the balance.
        uint256 balance0Adjusted = (balance0 * BASE) - (amount0In * SWAP_FEES);
        uint256 balance1Adjusted = (balance1 * BASE) - (amount1In * SWAP_FEES);
        // Ensure that new balances must increase by 0.3% of the amount in. Each term is scaled by 1000.
        require(
            (balance0Adjusted * balance1Adjusted) >= (uint256(_reserve0) * _reserve1 * (BASE ** 2)), "UniswapPair: K"
        );
        // Update reserves with current balances
        _update(balance0, balance1, _reserve0, _reserve1);
        emit Swap(msg.sender, amount0In, amount1In, amount0Out, amount1Out, to);
    }

    /**
     * @dev Initiate a flash loan
     * @param receiver The receiver of the tokens in the loan, and the receiver of the callback.
     * @param token The loan currency of the flash loan.
     * @param amount The amount of tokens lent in flash loan.
     * @param data Arbitrary data structure, data to send to receiver.
     *
     * Note:
     * Someone might call `flashLoan` with unsupported token, so checks for token.
     * Checks that the amount to loan out does not exceed `maxFlashLoan`.
     * The borrower borrows and must pay back the loan plus the fee atomically. We will be the ones to
     * transfer to them and transfer back from them. Cannot assume that they will return the loan.
     * Important to use `safeTransferFrom` to get loaned tokens back.
     */
    function flashLoan(
        IERC3156FlashBorrower receiver,
        address token,
        uint256 amount,
        bytes calldata data
    )
        external
        override
        nonReentrant
        returns (bool)
    {
        require(token == token0 || token == token1, "UniswapPair: token must be either token0 or token1");
        require(amount <= maxFlashLoan(token), "UniswapPair: amount exceeds maxFlashLoan");
        uint256 fee = _flashFee(amount);
        SafeTransferLib.safeTransfer(token, address(receiver), amount); //loan out
        //receiver callback
        require(
            receiver.onFlashLoan(msg.sender, token, amount, fee, data) == CALLBACK_SUCCESS,
            "UniswapPair: flash loan callback failed"
        );
        SafeTransferLib.safeTransferFrom(token, address(receiver), address(this), amount + fee); //repays loan

        emit FlashLoan(address(receiver), token, amount, fee, data);
        return true;
    }

    /**
     * For the given token, how much interest is charged on the flash loan.
     * Units are in token quantity, not in interest rate.
     */
    function flashFee(address token, uint256 amount) external view returns (uint256) {
        require(token == token0 || token == token1, "UniswapPair: token must be either token0 or token1");
        return _flashFee(amount);
    }

    //****************************************************************************************************
    //**************************************** PUBLIC FUNCTIONS ******************************************
    //****************************************************************************************************

    function getReserves() public view returns (uint112, uint112, uint32) {
        uint112 _reserve0 = reserve0;
        uint112 _reserve1 = reserve1;
        uint32 _blockTimestampLast = blockTimestampLast;
        return (_reserve0, _reserve1, _blockTimestampLast);
    }

    /**
     * Note:
     * For the given token, the maximum that can be flash loaned out.
     * Returns 0 if reserve amount is not sufficient.
     */
    function maxFlashLoan(address tokenToLoan) public view returns (uint256) {
        uint256 reserveAmount = (tokenToLoan == token0) ? reserve0 : reserve1;
        if (reserveAmount > MINIMUM_LIQUIDITY) {
            return reserveAmount - MINIMUM_LIQUIDITY;
        }
        return 0;
    }

    //****************************************************************************************************
    //*********************************** INTERNAL & PRIVATE FUNCTIONS ***********************************
    //****************************************************************************************************

    /**
     * Note: Updates the reserves.
     * TWAP oracle usage. Invoked on `mint`, `burn`, `swap`, `sync`.
     * Allow overflow, by leveraging on modular arithmetic props of uint32: it wraps around after exceeding
     * max value of uint32 (2^32 - 1). Enables `timeElapsed` to be calculated correctly.
     *
     * price(foo) = reserve(bar) / reserve(foo)
     */
    function _update(uint256 balance0, uint256 balance1, uint112 _reserve0, uint112 _reserve1) private {
        uint32 blockTimestamp = uint32(block.timestamp);
        unchecked {
            uint32 timeElapsed = blockTimestamp - blockTimestampLast;
            if (timeElapsed > 0 && _reserve0 != 0 && _reserve1 != 0) {
                // * never overflows, and + overflow is desired
                price0CumulativeLast += uint256(UQ112x112.encode(_reserve1).uqdiv(_reserve0)) * timeElapsed;
                price1CumulativeLast += uint256(UQ112x112.encode(_reserve0).uqdiv(_reserve1)) * timeElapsed;
            }
        }
        reserve0 = uint112(balance0);
        reserve1 = uint112(balance1);
        blockTimestampLast = blockTimestamp;

        emit Sync(reserve0, reserve1);
    }

    /**
     * Note:
     * If fee is on, mint liquidity equivalent to 1/6th of the growth in sqrt(k).
     *
     * If `rootK` is gt `rootKLast`, this implies liquidity pool has grown and a fee can be minted to `feeTo`.
     * The fee is calculatated as a fraction of the increase in liquidity, specifically, it is proportional to the
     * increase in sqrt(k), adjusted by the `totalSupply()` of the pool and a denominator which is the sum of the
     * previous sqrt(k) and the current sqrt(k).
     *
     * The use of `rootK` and `rootKLast` in the denominator ensures that the fee is proportional to the increase
     * in sqrt(k) per liquidity token, giving the fee a logical fraction of the total pool (both the current state
     * and the historical state of the pool).
     *
     * By making the fee dependent on the growth of the pool over time, this formula reduces the potential for
     * manipulation by making it less profitable to artificially inflate the pool size temporarily just before the
     * fee calculation.
     *
     * `liquidity` is the liquidity fee to `feeTo`.
     */
    function _mintFee(uint112 _reserve0, uint112 _reserve1) private returns (bool) {
        address feeTo = IUniswapFactory(factory).feeTo();
        bool feeOn = feeTo != address(0);
        uint256 _kLast = kLast; // gas savings
        if (feeOn) {
            if (_kLast != 0) {
                uint256 rootK = FixedPointMathLib.sqrt(uint256(_reserve0) * _reserve1); //current K
                uint256 rootKLast = FixedPointMathLib.sqrt(_kLast); //previous K
                if (rootK > rootKLast) {
                    uint256 numerator = totalSupply() * (rootK - rootKLast);
                    uint256 denominator = (rootK * PROTOCOL_FEE) + rootKLast;
                    uint256 liquidity = numerator / denominator;
                    if (liquidity > 0) {
                        _mint(feeTo, liquidity);
                        return true;
                    }
                }
            }
        } else if (_kLast != 0) {
            // Resets `kLast` to 0 if fee is off and `_kLast` is not 0.
            kLast = 0;
        }
        return feeOn;
    }

    function _flashFee(uint256 amount) private pure returns (uint256) {
        return amount * SWAP_FEES / BASE;
    }
}

//To do:
//`burn` shluld have slippage check
//`totalCupply` should have slippage checks
//On swap,
//The amountIn is not enforce to be optimal, so the user might overpay for the swap
//AmountOut has no flexibility as it is supplied as a parameter argument.
//If the amountIn turns out to not be sufficient relative to amountOut, the transaction will revert and gas will be wasted.
