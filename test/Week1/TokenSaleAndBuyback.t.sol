// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {TokenSaleAndBuyback} from "../../src/Week1/TokenSaleAndBuyback.sol";
import {MockERC1363} from "../mocks/MockERC1363.sol";

//forge test --match-contract TokenSaleAndBuybackTest -vvvv
contract TokenSaleAndBuybackTest is Test {
    TokenSaleAndBuyback tokenSaleAndBuyback;
    MockERC1363 reserveToken;
    address owner;
    address buyer1;
    address buyer2;
    uint256 startingReserveBalance;

    function setUp() public {
        owner = address(this);
        buyer1 = address(0x1);
        buyer2 = address(0x2);
        reserveToken = new MockERC1363();
        reserveToken.mint(buyer1, 100e18);
        reserveToken.mint(buyer2, 100e18);
        tokenSaleAndBuyback = new TokenSaleAndBuyback(address(reserveToken));
        startingReserveBalance = tokenSaleAndBuyback.reserveBalance();
    }

    function testUpdateInterval() public {
        vm.prank(buyer1);
        vm.expectRevert();
        tokenSaleAndBuyback.updateInterval(5);

        vm.startPrank(owner);
        vm.expectRevert("Interval must be greater than zero");
        tokenSaleAndBuyback.updateInterval(0);
        tokenSaleAndBuyback.updateInterval(2);
        vm.stopPrank();
        assertEq(tokenSaleAndBuyback.interval(), 2 days);
    }

    function testUpdateReserveRatio() public {
        vm.prank(buyer2);
        vm.expectRevert();
        tokenSaleAndBuyback.updateReserveRatio(1);

        vm.startPrank(owner);
        vm.expectRevert("Reserve ratio must be greater than zero");
        tokenSaleAndBuyback.updateReserveRatio(0);
        vm.expectRevert("Reserve ratio must be less than or equal to 1000000");
        tokenSaleAndBuyback.updateReserveRatio(1000001);
        tokenSaleAndBuyback.updateReserveRatio(700000);
        vm.stopPrank();
        assertEq(tokenSaleAndBuyback.reserveRatio(), 700000);
    }

    function testBuyOne() public {
        vm.startPrank(buyer1);
        uint256 buyAmount = 1e18;
        reserveToken.approve(address(tokenSaleAndBuyback), 100e18);

        uint256 previewMintedCTAmount = tokenSaleAndBuyback.calculateMintAmount(buyAmount);
        tokenSaleAndBuyback.buy(buyAmount);
        assertEq(reserveToken.balanceOf(address(buyer1)), 99e18);
        assertEq(reserveToken.balanceOf(address(tokenSaleAndBuyback)), buyAmount);
        assertEq(tokenSaleAndBuyback.balanceOf(buyer1), previewMintedCTAmount);
        assertEq(tokenSaleAndBuyback.reserveBalance(), startingReserveBalance + buyAmount);
        vm.stopPrank();

        vm.startPrank(buyer2);
        vm.expectRevert("Cannot mint zero tokens");
        tokenSaleAndBuyback.buy(0);
        vm.stopPrank();
    }

    function testBuyOneAndSellOne() public {
        vm.startPrank(buyer1);
        uint256 buyAmount = 1e18;
        reserveToken.approve(address(tokenSaleAndBuyback), 100e18);

        uint256 previewMintedCTAmount = tokenSaleAndBuyback.calculateMintAmount(buyAmount);
        tokenSaleAndBuyback.buy(buyAmount);

        //Post buyer1 buy:
        uint256 reserveTokenBuyerBal_1 = reserveToken.balanceOf(address(buyer1));
        uint256 reserveContractBal_1 = reserveToken.balanceOf(address(tokenSaleAndBuyback));
        uint256 reserveCurveBalance_1 = tokenSaleAndBuyback.reserveBalance();

        vm.expectRevert("Must wait for interval to pass");
        tokenSaleAndBuyback.burn(previewMintedCTAmount);

        vm.warp(block.timestamp + 1 days);

        vm.expectRevert("Cannot burn zero tokens");
        tokenSaleAndBuyback.burn(0);

        vm.expectRevert("Cannot burn more than balance");
        tokenSaleAndBuyback.burn(previewMintedCTAmount + 1);

        uint256 previewReturnedReserveAmount = tokenSaleAndBuyback.calculateBurnAmount(previewMintedCTAmount);
        tokenSaleAndBuyback.burn(previewMintedCTAmount);
        vm.stopPrank();

        /**
         * After burning, buyer 1 reseve token balanace should be his post-buy reserve token balance + the amount of
         * reserve tokens received from burning CTs.
         */
        assertEq(reserveToken.balanceOf(address(buyer1)), reserveTokenBuyerBal_1 + previewReturnedReserveAmount);
        /**
         * After buyer 1 burns CTs, the tokenSaleAndBuyback contract's should return reserve tokens and it's
         * reserve token balance should be the post-buy reserve token balance - the amount of reserve token
         * returned to the buyer.
         */
        assertEq(
            reserveToken.balanceOf(address(tokenSaleAndBuyback)), reserveContractBal_1 - previewReturnedReserveAmount
        );
        /**
         * After burning, buyer 1 should have no CTs.
         */
        assertEq(tokenSaleAndBuyback.balanceOf(buyer1), 0);
        /**
         * After burning, the tokenSaleAndBuyback contract's reserveBalance (not the ERC1363's, but it's own storage variable)
         * should be the post-buy value - the amount of reserve tokens returned to the buyer.
         */
        assertEq(tokenSaleAndBuyback.reserveBalance(), reserveCurveBalance_1 - previewReturnedReserveAmount);
    }

    function testBuyThreeTimes() public {
        vm.startPrank(buyer1);
        uint256 buyAmount = 10e18;
        reserveToken.approve(address(tokenSaleAndBuyback), 100e18);

        uint256 mintAmount1 = tokenSaleAndBuyback.calculateMintAmount(buyAmount);
        tokenSaleAndBuyback.buy(buyAmount);

        uint256 mintAmount2 = tokenSaleAndBuyback.calculateMintAmount(buyAmount);
        tokenSaleAndBuyback.buy(buyAmount);

        uint256 mintAmount3 = tokenSaleAndBuyback.calculateMintAmount(buyAmount);
        tokenSaleAndBuyback.buy(buyAmount);

        /**
         * If the buy amount remains the same, the mint amount should decrease each time since the
         * price of the CT token increases with each buy.
         */
        assertGt(mintAmount1, mintAmount2);
        assertGt(mintAmount2, mintAmount3);
        assertGt((mintAmount1 - mintAmount2), (mintAmount2 - mintAmount3));
    }

    function testLinear() public {
        vm.startPrank(buyer1);
        uint256 buyAmount = 10e18;
        reserveToken.approve(address(tokenSaleAndBuyback), 100e18);
        tokenSaleAndBuyback.buy(buyAmount);
        uint256 ctPrice1 = tokenSaleAndBuyback.getContinuousTokenPrice();
        vm.warp(block.timestamp + 1 days);
        tokenSaleAndBuyback.burn(tokenSaleAndBuyback.balanceOf(buyer1));
        uint256 ctPrice2 = tokenSaleAndBuyback.getContinuousTokenPrice();
        assertEq(ctPrice1, ctPrice2);
    }

    function testProfit() public {
        vm.startPrank(buyer1);
        uint256 buyer1InitialBalance = reserveToken.balanceOf(buyer1);
        uint256 buyAmount = 10e18;
        reserveToken.approve(address(tokenSaleAndBuyback), 100e18);
        tokenSaleAndBuyback.buy(buyAmount);
        vm.stopPrank();

        vm.startPrank(buyer2);
        reserveToken.approve(address(tokenSaleAndBuyback), 100e18);
        tokenSaleAndBuyback.buy(buyAmount);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(buyer1);
        tokenSaleAndBuyback.burn(tokenSaleAndBuyback.balanceOf(buyer1));
        vm.stopPrank();
        uint256 buyer1FinalBalance = reserveToken.balanceOf(buyer1);

        /**
         * Buyer 1's final balance should be greater than his initial balance since
         * buyer 1 bought CTs at a lower price, before buyer 2's buy.
         */
        assertGt(buyer1FinalBalance, buyer1InitialBalance);
    }
}
