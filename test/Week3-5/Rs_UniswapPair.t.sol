//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {UniswapFactory} from "../../src/Week3-5/Rs_UniswapFactory.sol";
import {UniswapPair} from "../../src/Week3-5/Rs_UniswapPair.sol";
import {UniToken} from "../../src/Week3-5/Rs_UniToken.sol";
import {Borrower} from "../../src/Week3-5/Borrower.sol";
import {FalseBorrower} from "./FalseBorrower.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

//forge test --via-ir --match-contract UniswapPairTest -vvvv
contract UniswapPairTest is Test {
    address public owner;
    address public user1;
    address public user2;
    address public feeCollector;
    UniswapFactory public factory;
    UniswapPair public pair;
    MockERC20 public tokenA;
    MockERC20 public tokenB;

    function setUp() external {
        owner = address(this);
        user1 = address(0x01);
        user2 = address(0x02);
        feeCollector = address(0x03);
        tokenA = new MockERC20();
        tokenB = new MockERC20();
        factory = new UniswapFactory(owner);
        pair = UniswapPair(factory.createPair(address(tokenA), address(tokenB)));

        deal(address(tokenA), owner, 1_000_000_000 * 10 ** 18);
        deal(address(tokenB), owner, 1_000_000_000 * 10 ** 18);
        deal(address(tokenA), user1, 1_000_000_000 * 10 ** 18);
        deal(address(tokenB), user1, 1_000_000_000 * 10 ** 18);
        deal(address(tokenA), user2, 1_000_000_000 * 10 ** 18);
        deal(address(tokenB), user2, 1_000_000_000 * 10 ** 18);
    }

    function testFactoryFeeToSetter() public {
        vm.expectRevert("UniswapFactory: Cannot set feeToSetter to zero address");
        UniswapFactory _factory = new UniswapFactory(address(0));

        vm.startPrank(owner);
        vm.expectRevert("UniswapFactory: Cannot set feeToSetter to zero address");
        factory.setFeeToSetter(address(0));
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert("UniswapFactory: Not authorized to set feeToSetter");
        factory.setFeeToSetter(user1);
    }

    function testFactoryCreatePair() public {
        vm.expectRevert("UniswapFactory: Cannot create pair with same token");
        UniswapPair _pair1 = UniswapPair(factory.createPair(address(tokenA), address(tokenA)));

        vm.expectRevert("UniswapFacory: Cannot create pair with zero address");
        UniswapPair _pair2 = UniswapPair(factory.createPair(address(tokenA), address(0)));

        vm.expectRevert("UniswapFactory: Pair already exists in contract");
        UniswapPair _pair3 = UniswapPair(factory.createPair(address(tokenA), address(tokenB)));
    }

    function testFirstLiquidityProvider() external {
        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            500 * 10 ** 18,
            900 * 10 ** 18,
            400 * 10 ** 18,
            block.timestamp
        );
        vm.stopPrank();
        uint256 lPTokenBalance = pair.balanceOf(user1);
        assertGt(lPTokenBalance, 0);
    }

    function testSecondLiquidityProviderWithExactRatio() external {
        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            500 * 10 ** 18,
            900 * 10 ** 18, //slippage
            400 * 10 ** 18, //slippage
            block.timestamp
        );
        vm.stopPrank();

        vm.startPrank(user2);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            500 * 10 ** 18,
            900 * 10 ** 18, //slippage
            400 * 10 ** 18, //slippage
            block.timestamp
        );
        vm.stopPrank();

        uint256 lPTokenBalanceUser1 = pair.balanceOf(user1);
        uint256 lPTokenBalanceUser2 = pair.balanceOf(user2);
        assertGt(lPTokenBalanceUser2, 0);

        uint256 absoluteDifference;
        if (lPTokenBalanceUser1 > lPTokenBalanceUser2) {
            absoluteDifference = lPTokenBalanceUser1 - lPTokenBalanceUser2;
        } else {
            absoluteDifference = lPTokenBalanceUser2 - lPTokenBalanceUser1;
        }
        uint256 largerNumber = lPTokenBalanceUser1 > lPTokenBalanceUser2 ? lPTokenBalanceUser1 : lPTokenBalanceUser2;
        //0.0000001%
        uint256 oneHundredthPercentOfLarger = largerNumber / 1000000000;
        //Since both liquidity providers provided same ratio, the difference should be almost nonexistent
        assertLt(absoluteDifference, oneHundredthPercentOfLarger);
    }

    function testSecondLiquidityProviderWithWrongRatio() external {
        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            500 * 10 ** 18,
            900 * 10 ** 18, //slippage
            400 * 10 ** 18, //slippage
            block.timestamp
        );
        vm.stopPrank();

        vm.startPrank(user2);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_200 * 10 ** 18,
            450 * 10 ** 18,
            700 * 10 ** 18, //slippage
            400 * 10 ** 18, //slippage
            block.timestamp
        );
        vm.stopPrank();

        uint256 lPTokenBalanceUser1 = pair.balanceOf(user1);
        uint256 lPTokenBalanceUser2 = pair.balanceOf(user2);
        //If wrong ratio provided, the second liquidity provider should get less lp tokens
        assertGt(lPTokenBalanceUser1, lPTokenBalanceUser2);
    }

    function testMintWithDeadlinePassed() external {
        vm.warp(10 days);
        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        vm.expectRevert("UniswapPair: TIMELOCK");
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            500 * 10 ** 18,
            900 * 10 ** 18, //slippage
            400 * 10 ** 18, //slippage
            block.timestamp - 0.5 days
        );
        vm.stopPrank();
    }

    function testMintZeroAddress() external {
        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        vm.expectRevert("UniswapPair: ZERO_ADDRESS");
        pair.mint(
            address(0),
            address(tokenB),
            1_000 * 10 ** 18,
            500 * 10 ** 18,
            900 * 10 ** 18, //slippage
            400 * 10 ** 18, //slippage
            block.timestamp
        );
        vm.expectRevert("UniswapPair: ZERO_ADDRESS");
        pair.mint(
            address(tokenA),
            address(0),
            1_000 * 10 ** 18,
            500 * 10 ** 18,
            900 * 10 ** 18, //slippage
            400 * 10 ** 18, //slippage
            block.timestamp
        );
        vm.stopPrank();
    }

    function testMintIdenticalAddress() external {
        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        vm.expectRevert("UniswapPair: IDENTICAL_ADDRESSES");
        pair.mint(
            address(tokenA),
            address(tokenA),
            1_000 * 10 ** 18,
            500 * 10 ** 18,
            900 * 10 ** 18, //slippage
            400 * 10 ** 18, //slippage
            block.timestamp
        );
        vm.stopPrank();
    }

    function testMintSlippage() external {
        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            1_000 * 10 ** 18,
            1_000 * 10 ** 18, //slippage
            1_000 * 10 ** 18, //slippage
            block.timestamp
        );
        vm.expectRevert("UniswapPair: SLIPPAGE_AMOUNT1");
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            1_000 * 10 ** 18,
            1_000 * 10 ** 18, //slippage
            1_001 * 10 ** 18, //slippage
            block.timestamp
        );
        vm.expectRevert("UniswapPair: SLIPPAGE_AMOUNT0_MIN");
        pair.mint(
            address(tokenA),
            address(tokenB),
            2_000 * 10 ** 18,
            1_000 * 10 ** 18,
            2_001 * 10 ** 18, //slippage
            1_000 * 10 ** 18, //slippage
            block.timestamp
        );
        vm.stopPrank();
    }

    function testMintFeeOn() external {
        vm.startPrank(owner);
        factory.setFeeTo(feeCollector);
        uint256 initialKLast = pair.kLast();
        uint256 initialFeeToAddressBalance = pair.balanceOf(feeCollector);

        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            500 * 10 ** 18,
            900 * 10 ** 18,
            400 * 10 ** 18,
            block.timestamp
        );

        uint256 finalKLast = pair.kLast();

        pair.mint(
            address(tokenA),
            address(tokenB),
            10_000 * 10 ** 18,
            5_000 * 10 ** 18,
            900 * 10 ** 18,
            400 * 10 ** 18,
            block.timestamp
        );
        uint256 checkKLast = pair.kLast();
        uint256 finalFeeToAddressBalance = pair.balanceOf(feeCollector);

        assertGt(finalKLast, initialKLast);
        //assertGt(finalFeeToAddressBalance, initialFeeToAddressBalance);
    }

    function testBurn() external {
        vm.startPrank(owner);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            500 * 10 ** 18,
            900 * 10 ** 18,
            400 * 10 ** 18,
            block.timestamp
        );
        vm.stopPrank();

        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            100 * 10 ** 18,
            50 * 10 ** 18,
            90 * 10 ** 18,
            40 * 10 ** 18,
            block.timestamp
        );

        uint256 tokenABalanceInitial = tokenA.balanceOf(user1);
        uint256 tokenBBalanceInitial = tokenB.balanceOf(user1);
        uint256 lPTokenBalanceInitial = pair.balanceOf(user1);

        pair.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.burn(lPTokenBalanceInitial, 99 * 10 ** 18, 49 * 10 ** 18, block.timestamp);
        vm.stopPrank();

        uint256 tokenABalanceFinal = tokenA.balanceOf(user1);
        uint256 tokenBBalanceFinal = tokenB.balanceOf(user1);
        uint256 lPTokenBalanceFinal = pair.balanceOf(user1);

        assertGt(tokenABalanceFinal, tokenABalanceInitial);
        assertGt(tokenBBalanceFinal, tokenBBalanceInitial);
        assertEq(lPTokenBalanceFinal, 0);
    }

    function testBurnWithDeadlinePassed() external {
        vm.startPrank(owner);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            500 * 10 ** 18,
            900 * 10 ** 18,
            400 * 10 ** 18,
            block.timestamp
        );
        vm.stopPrank();
        vm.warp(10 days);
        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);

        uint256 lPTokenBalanceInitial = pair.balanceOf(user1);

        pair.approve(address(pair), 1_000_000_000 * 10 ** 18);
        vm.expectRevert("UniswapPair: TIMELOCK");
        pair.burn(lPTokenBalanceInitial, 99 * 10 ** 18, 49 * 10 ** 18, block.timestamp - 0.5 days);
        vm.stopPrank();
    }

    function testBurnSlippageAndInsufficientBurn() external {
        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            100 * 10 ** 18,
            100 * 10 ** 18,
            90 * 10 ** 18,
            90 * 10 ** 18,
            block.timestamp
        );
        uint256 lPTokenBalanceInitial = pair.balanceOf(user1);

        pair.approve(address(pair), 1_000_000_000 * 10 ** 18);

        vm.expectRevert("UniswapPair: SLIPPAGE_AMOUNT0");
        pair.burn(lPTokenBalanceInitial, 101 * 10 ** 18, 49 * 10 ** 18, block.timestamp);

        vm.expectRevert("UniswapPair: SLIPPAGE_AMOUNT1");
        pair.burn(lPTokenBalanceInitial, 99 * 10 ** 18, 101 * 10 ** 18, block.timestamp);

        vm.expectRevert("UniswapPair: INSUFFICIENT_LIQUIDITY_BURNED");
        pair.burn(0, 0, 0, block.timestamp);

        vm.stopPrank();
    }

    function testBurnFeeOn() external {
        vm.startPrank(owner);
        factory.setFeeTo(feeCollector);
        uint256 initialKLast = pair.kLast();
        uint256 initialFeeToAddressBalance = pair.balanceOf(feeCollector);

        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            1_00 * 10 ** 18,
            900 * 10 ** 18,
            900 * 10 ** 18,
            block.timestamp
        );
        uint256 lPTokenBalanceInitial = pair.balanceOf(user1);
        uint256 updatedKLast = pair.kLast();

        pair.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.burn(lPTokenBalanceInitial, 99 * 10 ** 18, 49 * 10 ** 18, block.timestamp);
        uint256 finalKLast = pair.kLast();
        uint256 finalFeeToAddressBalance = pair.balanceOf(feeCollector);

        assertGt(finalKLast, initialKLast);
        assertGt(updatedKLast, finalKLast);
    }

    function testSwapExactTokensInForTokenOut() external {
        vm.startPrank(owner);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            1_000 * 10 ** 18,
            900 * 10 ** 18,
            900 * 10 ** 18,
            block.timestamp
        );
        vm.stopPrank();
        vm.startPrank(user1);
        uint256 tokenABalanceInitial = tokenA.balanceOf(user1);
        uint256 tokenBBalanceInitial = tokenB.balanceOf(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.swapExactTokensInForTokensOut(
            100 * 10 ** 18, 90 * 10 ** 18, address(tokenA), address(tokenB), block.timestamp
        );
        uint256 tokenABalanceFinal = tokenA.balanceOf(user1);
        uint256 tokenBBalanceFinal = tokenB.balanceOf(user1);
        assertGt(tokenABalanceInitial, tokenABalanceFinal);
        assertGt(tokenBBalanceFinal, tokenBBalanceInitial);
    }

    function testSwapExactTokensInForTokensOutInsufficientIOAmounts() external {
        vm.startPrank(owner);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            1_000 * 10 ** 18,
            900 * 10 ** 18,
            900 * 10 ** 18,
            block.timestamp
        );
        vm.stopPrank();
        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        vm.expectRevert("UniswapPair: INSUFFICIENT_INPUT_AMOUNT");
        pair.swapExactTokensInForTokensOut(0, 90 * 10 ** 18, address(tokenA), address(tokenB), block.timestamp);
        vm.expectRevert("UniswapPair: INSUFFICIENT_OUTPUT_AMOUNT");
        pair.swapExactTokensInForTokensOut(
            100 * 10 ** 18, 100 * 10 ** 18, address(tokenA), address(tokenB), block.timestamp
        );
    }

    function testSwapExactTokensInForTokenOutDeadlinePassed() external {
        vm.warp(10 days);
        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        vm.expectRevert("UniswapPair: TIMELOCK");
        pair.swapExactTokensInForTokensOut(0, 90 * 10 ** 18, address(tokenA), address(tokenB), block.timestamp - 1 days);
    }

    function testSwapExactTokensInForTokenOutIdenticalTokens() external {
        vm.startPrank(owner);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            1_000 * 10 ** 18,
            900 * 10 ** 18,
            900 * 10 ** 18,
            block.timestamp
        );
        vm.stopPrank();
        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        vm.expectRevert("UniswapPair: IDENTICAL_ADDRESSES");
        pair.swapExactTokensInForTokensOut(
            100 * 10 ** 18, 90 * 10 ** 18, address(tokenA), address(tokenA), block.timestamp
        );
    }

    function testSwapExactTokensInForTokenOutNoReserves() external {
        vm.startPrank(owner);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        vm.expectRevert("UniswapPair: INSUFFICIENT_LIQUIDITY");
        pair.swapExactTokensInForTokensOut(
            100 * 10 ** 18, 90 * 10 ** 18, address(tokenA), address(tokenB), block.timestamp
        );
    }

    function testSwapTokensInForExactTokensOut() external {
        vm.startPrank(owner);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            1_000 * 10 ** 18,
            999 * 10 ** 18,
            999 * 10 ** 18,
            block.timestamp
        );
        vm.stopPrank();
        vm.startPrank(user1);
        uint256 tokenABalanceInitial = tokenA.balanceOf(user1);
        uint256 tokenBBalanceInitial = tokenB.balanceOf(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.swapTokensInForExactTokensOut(
            90 * 10 ** 18, 100 * 10 ** 18, address(tokenA), address(tokenB), block.timestamp
        );
        uint256 tokenABalanceFinal = tokenA.balanceOf(user1);
        uint256 tokenBBalanceFinal = tokenB.balanceOf(user1);
        assertGt(tokenABalanceInitial, tokenABalanceFinal);
        assertGt(tokenBBalanceFinal, tokenBBalanceInitial);
    }

    function testSwapTokensInForExactTokensOutInsufficientIOAmounts() external {
        vm.startPrank(owner);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            1_000 * 10 ** 18,
            999 * 10 ** 18,
            999 * 10 ** 18,
            block.timestamp
        );
        vm.stopPrank();
        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        vm.expectRevert("UniswapPair: INSUFFICIENT_OUTPUT_AMOUNT");
        pair.swapTokensInForExactTokensOut(0, 100 * 10 ** 18, address(tokenA), address(tokenB), block.timestamp);
        vm.expectRevert("UniswapPair: EXCESSIVE_INPUT_AMOUNT");
        pair.swapTokensInForExactTokensOut(
            100 * 10 ** 18, 100 * 10 ** 18, address(tokenA), address(tokenB), block.timestamp
        );
    }

    function testSwapTokensInForExactTokensOutDeadlinePassed() external {
        vm.warp(10 days);
        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        vm.expectRevert("UniswapPair: TIMELOCK");
        pair.swapTokensInForExactTokensOut(
            90 * 10 ** 18, 100 * 10 ** 18, address(tokenA), address(tokenB), block.timestamp - 1 days
        );
    }

    function testSwapTokensInForExactTokensOutIdenticalTokens() external {
        vm.startPrank(owner);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            1_000 * 10 ** 18,
            900 * 10 ** 18,
            900 * 10 ** 18,
            block.timestamp
        );
        vm.stopPrank();
        vm.startPrank(user1);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        vm.expectRevert("UniswapPair: IDENTICAL_ADDRESSES");
        pair.swapTokensInForExactTokensOut(
            90 * 10 ** 18, 100 * 10 ** 18, address(tokenA), address(tokenA), block.timestamp
        );
    }

    function testSwapTokensInForExactTokensOutNoReserves() external {
        vm.startPrank(owner);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        vm.expectRevert("UniswapPair: INSUFFICIENT_LIQUIDITY");
        pair.swapTokensInForExactTokensOut(
            90 * 10 ** 18, 100 * 10 ** 18, address(tokenA), address(tokenB), block.timestamp
        );
    }

    function testFlashLoanMagicValueFailed() external {
        vm.startPrank(owner);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            1_000 * 10 ** 18,
            999 * 10 ** 18,
            999 * 10 ** 18,
            block.timestamp
        );
        vm.stopPrank();
        vm.startPrank(user1);
        FalseBorrower borrower = new FalseBorrower(address(pair), user1);
        uint256 flashFees = pair.flashFee(address(tokenA), 50 * 10 ** 18);
        vm.expectRevert("UniswapPair: flash loan callback failed");
        pair.flashLoan(borrower, address(tokenA), 50 * 10 ** 18, "");
    }

    function testFlashLoanWrongToken() external {
        vm.startPrank(owner);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            1_000 * 10 ** 18,
            999 * 10 ** 18,
            999 * 10 ** 18,
            block.timestamp
        );
        vm.stopPrank();
        vm.startPrank(user1);
        Borrower borrower = new Borrower(address(pair), user1);
        uint256 flashFees = pair.flashFee(address(tokenA), 50 * 10 ** 18);
        vm.expectRevert("UniswapPair: token must be either token0 or token1");
        pair.flashLoan(borrower, address(0x572843023857abc), 50 * 10 ** 18, "");
    }

    function testFlashLoanAmountExceeded() external {
        vm.startPrank(owner);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            1_000 * 10 ** 18,
            999 * 10 ** 18,
            999 * 10 ** 18,
            block.timestamp
        );
        vm.stopPrank();
        vm.startPrank(user1);
        Borrower borrower = new Borrower(address(pair), user1);
        uint256 flashFees = pair.flashFee(address(tokenA), 50 * 10 ** 18);
        vm.expectRevert("UniswapPair: amount exceeds maxFlashLoan");
        pair.flashLoan(borrower, address(tokenA), 1_001 * 10 ** 18, "");
    }

    function testFlashLoan() external {
        vm.startPrank(owner);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            1_000 * 10 ** 18,
            999 * 10 ** 18,
            999 * 10 ** 18,
            block.timestamp
        );
        vm.stopPrank();

        vm.startPrank(user1);
        Borrower borrower = new Borrower(address(pair), user1);
        tokenA.transfer(address(borrower), 100 * 10 ** 18);
        uint256 tokenABalanceInitial = tokenA.balanceOf(address(borrower));

        uint256 flashFees = pair.flashFee(address(tokenA), 50 * 10 ** 18);
        pair.flashLoan(borrower, address(tokenA), 20 * 10 ** 18, "");

        uint256 tokenABalanceFinal = tokenA.balanceOf(address(borrower));
        assertLt(tokenABalanceFinal, tokenABalanceInitial);
    }

    function testMaxFlashLoan() external {
        vm.startPrank(owner);
        tokenA.approve(address(pair), 1_000_000_000 * 10 ** 18);
        tokenB.approve(address(pair), 1_000_000_000 * 10 ** 18);
        uint256 liquidity = pair.mint(
            address(tokenA),
            address(tokenB),
            1_000 * 10 ** 18,
            1_000 * 10 ** 18,
            999 * 10 ** 18,
            999 * 10 ** 18,
            block.timestamp
        );
        vm.stopPrank();

        address nonPairToken = address(0x0123);
        vm.expectRevert("UniswapPair: token must be either token0 or token1");
        assertEq(pair.maxFlashLoan(nonPairToken), 0);

        assertLt(pair.maxFlashLoan(address(tokenA)), 1_000 * 10 ** 18);
        assertLt(pair.maxFlashLoan(address(tokenB)), 1_000 * 10 ** 18);
        assertGt(pair.maxFlashLoan(address(tokenA)), 900 * 10 ** 18);
        assertGt(pair.maxFlashLoan(address(tokenB)), 900 * 10 ** 18);

        vm.startPrank(owner);
        pair.burn(liquidity, 0, 0, block.timestamp);
        assertEq(pair.maxFlashLoan(address(tokenA)), 0);
    }

    function testCalculateForAmountOut() public {
        TestInternalFunctions _pair = new TestInternalFunctions();
        vm.expectRevert("UniswapPair: INSUFFICIENT_INPUT_AMOUNT");
        _pair.testCalculateForAmountOut(0, 100, 100);
        vm.expectRevert("UniswapPair: INSUFFICIENT_LIQUIDITY");
        _pair.testCalculateForAmountOut(100, 0, 100);

        uint256 amountOut = _pair.testCalculateForAmountOut(10, 100, 100);
        assertEq(amountOut, 9);
    }

    function testCalculateForAmountIn() public {
        TestInternalFunctions _pair = new TestInternalFunctions();
        vm.expectRevert("UniswapPair: INSUFFICIENT_OUTPUT_AMOUNT");
        _pair.testCalculateForAmountIn(0, 100, 100);
        vm.expectRevert("UniswapPair: INSUFFICIENT_LIQUIDITY");
        _pair.testCalculateForAmountIn(100, 0, 100);

        uint256 amountIn = _pair.testCalculateForAmountIn(10, 100, 100);
        assertEq(amountIn, 12);
    }

    function testUpdateBorrower() public {
        Borrower borrower = new Borrower(address(pair), user1);
        vm.expectRevert("Borrower: trustedInitiator cannot be the zero address");
        borrower.updateTrustedInitiator(address(0));
        vm.expectRevert("Borrower: lender cannot be the zero address");
        borrower.updateLender(address(0));
        vm.startPrank(user2);
        vm.expectRevert();
        borrower.updateTrustedInitiator(user2);
        vm.expectRevert();
        borrower.updateLender(user2);
    }

    receive() external payable {}
}

contract TestInternalFunctions is UniswapPair {
    function testCalculateForAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    )
        public
        returns (uint256)
    {
        return super.calculateForAmountOut(amountIn, reserveIn, reserveOut);
    }

    function testCalculateForAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    )
        public
        returns (uint256)
    {
        return super.calculateForAmountIn(amountOut, reserveIn, reserveOut);
    }
}
