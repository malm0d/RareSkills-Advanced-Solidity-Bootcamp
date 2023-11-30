//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {UniswapFactory} from "../../src/Week3-5/Rs_UniswapFactory.sol";
import {UniswapPair} from "../../src/Week3-5/Rs_UniswapPair.sol";
import {UniToken} from "../../src/Week3-5/Rs_UniToken.sol";
import {Borrower} from "../../src/Week3-5/Borrower.sol";
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

    function testSwapExactTokensInForTokenOutInsufficientIOAmounts() external {
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
        uint256 tokenABalanceInitial = tokenA.balanceOf(user1);
        uint256 tokenBBalanceInitial = tokenB.balanceOf(user1);
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
            500 * 10 ** 18,
            900 * 10 ** 18,
            400 * 10 ** 18,
            block.timestamp
        );
        vm.stopPrank();
    }

    receive() external payable {}
}
