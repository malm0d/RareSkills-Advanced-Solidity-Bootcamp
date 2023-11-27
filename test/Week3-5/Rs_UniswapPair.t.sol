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
    UniswapFactory public factory;
    UniswapPair public pair;
    MockERC20 public tokenA;
    MockERC20 public tokenB;

    function setUp() external {
        owner = address(this);
        user1 = address(0x01);
        user2 = address(0x02);
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

    function testSwapExactTokensInForTokenOut() external {
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
}
