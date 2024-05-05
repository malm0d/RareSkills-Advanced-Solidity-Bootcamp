//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OrderBook is EIP712, Nonces {
    using SafeERC20 for IERC20;

    error SignatureExpired();
    error InvalidSignature();
    error InvalidSignatureLength();
    error OrderMismatch();
    error PermitOrderMismatch();
    error PriceMismatch();

    event MatchedOrderExecuted();

    uint256 internal constant WAD = 1e18;

    IERC20 public tokenA;
    IERC20 public tokenB;

    /**
     * @dev 
     * `maker`: the address that created the order
     * `deadline`: the timestamp after which the order is invalid
     * `nonce`: maker's nonce
     */
    struct Order {
        address maker;
        uint256 deadline;
        address sellToken;
        address buyToken;
        uint256 sellTokenAmount;
        uint256 buyTokenAmount;
        uint256 nonce;
    }

    struct Permit {
        address tokenAddr;
        address owner; //`owner` of the tokens
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;
    }

    ///@dev EIP-712 `typehash`: keccak256(encodeType(typeOf(struct)))
    ///https://eips.ethereum.org/EIPS/eip-712
    //keccak256(bytes(String))?
    bytes32 private constant ORDER_TYPEHASH = keccak256(
        "Order(address maker,uint256 deadline,address sellToken,address buyToken,uint256 sellTokenAmount,uint256 buyTokenAmount,uint256 nonce)"
    );

    constructor(
        address _tokenA,
        address _tokenB
    ) EIP712("OrderBook", "1") {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function executeMatchedOrder(
        Permit memory sellPermit,
        Order memory sellOrder,
        bytes memory sellSignature,
        Permit memory buyPermit,
        Order memory buyOrder,
        bytes memory buySignature
    ) external {
        //Validate signatures
        {
            (bytes32 r_Sell, bytes32 s_Sell, uint8 v_Sell) = _splitSignature(sellSignature);
            _validateSignature(sellOrder, r_Sell, s_Sell, v_Sell);

            (bytes32 r_Buy, bytes32 s_Buy, uint8 v_Buy) = _splitSignature(buySignature);
            _validateSignature(buyOrder, r_Buy, s_Buy, v_Buy);
        }

        //Check orders and ratio
        _checkOrdersAndRatio(sellOrder, buyOrder);

        //Permit and order match are needed for both sell and buy orders
        //since funds are being transferred in both directions
        _chcekPermitAndOrderMatch(sellPermit, sellOrder);
        _chcekPermitAndOrderMatch(buyPermit, buyOrder);

        //Execute the permit for sell order
        _permitERC20(
            sellPermit.tokenAddr, 
            sellPermit.owner, 
            sellPermit.value, 
            sellPermit.deadline, 
            sellPermit.v, 
            sellPermit.r, 
            sellPermit.s
        );

        //Execute the permit for buy order
        _permitERC20(
            buyPermit.tokenAddr, 
            buyPermit.owner, 
            buyPermit.value, 
            buyPermit.deadline, 
            buyPermit.v, 
            buyPermit.r, 
            buyPermit.s
        );

        //Trade tokens from both parties
        _executeTrade(sellOrder, buyOrder);   

        emit MatchedOrderExecuted();
    }

    ///@dev When trade executes, sell order maker sells token A and buys token B,
    ///which also means the buy order maker buys token A and sells token B.
    ///Transfer flow:
    ///  Token A: Sell order maker -> Buy order maker (amountA)
    ///  Token B: Buy order maker -> Sell order maker (amountB)
    function _executeTrade(
        Order memory sellOrder,
        Order memory buyOrder
    ) internal {
        //Price of an order is the ratio of the exchange between the two tokens.
        //Sell price == how many of sell token to get 1 buy token.
        //Buy price == how many of buy token to get 1 sell token.
        uint256 sellPrice = divWad(sellOrder.sellTokenAmount, sellOrder.buyTokenAmount);
        uint256 buyPrice = divWad(buyOrder.buyTokenAmount, buyOrder.sellTokenAmount);

        //The sellPrice cannot be greater than the buyPrice, i.e: the price seller
        //is willing to sell cannot exceed the price buyer is willing to pay.
        if (sellPrice > buyPrice) {
            revert PriceMismatch();
        }

        //Calculate max possible amount of token A the sell order can trade (sell price * sell amount)
        //Seller wants to sell.
        uint256 maxAmountA = mulWad(sellPrice, sellOrder.sellTokenAmount);

        //Calculate the max possible amount of token B the buy order can trade (buy amount / buy price)
        //Buyer wants to buy
        uint256 maxAmountB = divWad(buyOrder.buyTokenAmount, buyPrice);

        //Determine actual amounts to be traded
        uint256 amountA;
        uint256 amountB;

        ///1. If the max amount of sell tokens that seller wants to sell is <= the total amount of sell tokens
        //that the buyer wants to buy, and the max amount of buy tokens that the buyer wants to buy is <= the
        //total amount of buy tokens that the seller wants to sell, then both `maxAmountA` and `maxAmountB` are
        //within order limits.
        if (maxAmountA <= buyOrder.sellTokenAmount && maxAmountB <= sellOrder.sellTokenAmount) {
            amountA = maxAmountA;
            amountB = maxAmountB;
        
        ///2. The buyer accepts the amount in `maxAmountB`, but the seller wants to sell more token A than 
        ///buyer is willing to buy; then we need to adjust `amountA` to match buyer's capacity to buy, i.e. 
        ///adjust amount for sell order (token A) based on the buyPrice and amount buyer agreed (token B).
        } else if (maxAmountA > buyOrder.sellTokenAmount && maxAmountB <= sellOrder.sellTokenAmount) {
            amountB = maxAmountB;
            amountA = mulWad(buyPrice, amountB); // Recalculate amountA based on buyPrice and the acceptable amountB
        
        ///3. The seller accepts the amount in `maxAmountA`, but the max amount of buy tokens that the buyer
        ///wants to buy > the total amount of buy tokens that the seller is able to sell, then we need to adjust
        ///`amountB` to match seller's capacity to sell, i.e. adjust amount for buy order (token B) based on the
        ///sellPrice and amount seller agreed (oken A).
        } else if (maxAmountA <= buyOrder.sellTokenAmount && maxAmountB > sellOrder.sellTokenAmount) {
            amountA = maxAmountA;
            amountB = divWad(amountA, sellPrice); // Recalculate amountB based on sellPrice and the acceptable amountA
        
        ///4. If both the seller and buyer want to trade more than the total amount of tokens they have, then
        ///just use the maximum amount of tokens they can trade.
        } else {
            amountA = buyOrder.sellTokenAmount;
            amountB = sellOrder.sellTokenAmount;
        }

        //Transfer tokens
        IERC20(sellOrder.sellToken).safeTransferFrom(sellOrder.maker, buyOrder.maker, amountA);
        IERC20(buyOrder.buyToken).safeTransferFrom(buyOrder.maker, sellOrder.maker, amountB);
    }

    ///@dev EIP712: https://eips.ethereum.org/EIPS/eip-712
    function _validateSignature(
        Order memory _order,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) internal {
        if (_order.deadline < block.timestamp) {
            revert SignatureExpired();
        }

        //EIP712: `encodeData(struct)`
        bytes32 structHash = keccak256(abi.encode(
            ORDER_TYPEHASH,
            _order.maker,
            _order.deadline,
            _order.sellToken,
            _order.buyToken,
            _order.sellTokenAmount,
            _order.buyTokenAmount,
            _useNonce(_order.maker)
        ));

        //EIP712: hash of fully encoded message
        //Using `_hashTypedDataV4` from O.Z will calculate the hash of the fully encoded message
        //according to standard with: "\x19\x01" ‖ domainSeparator ‖ hashStruct(message)
        bytes32 hash = _hashTypedDataV4(structHash);

        //Recover Signer address with ECDSA (O.Z.)
        //Avoid using ecrecover directly for malleability reasons
        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != _order.maker) {
            revert InvalidSignature();
        }
    }

    ///@dev split the signature into `r`, `s` and `v`
    function _splitSignature(
        bytes memory _signature
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        if (_signature.length != 65) {
            revert InvalidSignatureLength();
        }

        //First 32 bytes is the length of the bytes array.
        //So: add(_signature, 0x20) = pointer of signature + 32 bytes,
        //i.e. the start of `r` (and the actual signature itself).
        assembly {
            //First 32 bytes after length prefix is `r`.
            //Next 32 bytes is `s`.
            //Last byte is `v`.
            r := mload(add(_signature, 0x20))
            s := mload(add(_signature, 0x40))

            //Extract the most significant byte of the last 32 bytes (`v`)
            ///byte(n, x): extract the nth byte of x (n is the position of the byte in x)
            //where 0 is the most significant byte (leftmost)
            v := byte(0, mload(add(_signature, 0x60)))
        }
    }

    ///@dev the `owner` of the permit must be the `maker` of the order.
    ///Owner of the permit creates a signature that allows the `spender` to spend its tokens
    ///when an order(trade) is created. In this context, the `spender` is the `OrderBook` contract.
    ///Ensures that the address that created the permit is dealing with an order it created.
    function _chcekPermitAndOrderMatch (
        Permit memory permit,
        Order memory order
    ) internal pure {
        if (permit.owner != order.maker) {
            revert PermitOrderMismatch();
        }
    }

    ///@dev the `sellToken` of one order must be the `buyToken` of the other
    //and the `sellTokenAmount` and `buyTokenAmount` must be more than zero (cannot buy and sell for nothing).
    //Also need to check the raio so that a malicious actor cannot create and execute orders with
    //imbalanced ratios, causing one party to receive significantly more tokens for the trade.
    function _checkOrdersAndRatio (
        Order memory orderA,
        Order memory orderB
    ) internal pure {
        require(orderA.sellToken == orderB.buyToken, "Wrong token pair");
        require(orderA.buyToken == orderB.sellToken, "Wrong token pair");
        require(orderA.sellTokenAmount > 0, "Zero sell amount");
        require(orderB.buyTokenAmount > 0, "Zero buy amount");
        require(orderA.buyTokenAmount > 0, "Zero buy amount");
        require(orderB.sellTokenAmount > 0, "Zero sell amount");

        //If sell and buy amounts for first order is equal, then the second must follow suit
        if (orderA.sellTokenAmount == orderA.buyTokenAmount) {
            require(orderB.sellTokenAmount == orderB.buyTokenAmount, "Ratio mismatch");
        } else if (orderA.sellTokenAmount > orderA.buyTokenAmount) {
            uint256 ratioOrderA = orderA.sellTokenAmount / orderA.buyTokenAmount;
            uint256 ratioOrderB = orderB.buyTokenAmount / orderB.sellTokenAmount;
            require(ratioOrderA == ratioOrderB, "Ratio mismatch");
        } else {
            uint256 ratioOrderA = orderA.buyTokenAmount / orderA.sellTokenAmount;
            uint256 ratioOrderB = orderB.sellTokenAmount / orderB.buyTokenAmount;
            require(ratioOrderA == ratioOrderB, "Ratio mismatch");
        }
    }

    ///@dev executes ERC20Permit `permit`
    function _permitERC20(
        address tokenAddr,
        address owner,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        IERC20Permit(tokenAddr).permit(
            owner, //`owner` of the tokens
            address(this), //`spender` of the allowance
            value,
            deadline,
            v,
            r,
            s
        );
    }

    /// @dev `mulWad` from Solady
    /// @dev Equivalent to `(x * y) / WAD` rounded down.
    function mulWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to `require(y == 0 || x <= type(uint256).max / y)`.
            if mul(y, gt(x, div(not(0), y))) {
                mstore(0x00, 0xbac65e5b) // `MulWadFailed()`.
                revert(0x1c, 0x04)
            }
            z := div(mul(x, y), WAD)
        }
    }

    /// @dev `divWad` from Solady
    /// @dev Equivalent to `(x * WAD) / y` rounded down.
    function divWad(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Equivalent to `require(y != 0 && (WAD == 0 || x <= type(uint256).max / WAD))`.
            if iszero(mul(y, iszero(mul(WAD, gt(x, div(not(0), WAD)))))) {
                mstore(0x00, 0x7c5f487d) // `DivWadFailed()`.
                revert(0x1c, 0x04)
            }
            z := div(mul(x, WAD), y)
        }
    }
}