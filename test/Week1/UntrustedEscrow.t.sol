// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {UntrustedEscrow} from "../../src/Week1/UntrustedEscrow.sol";
import {MockERC20} from "../mocks/MockERC20.sol";

contract UntrustedEscrowTest is Test {
    UntrustedEscrow untrustedEscrow;
    address owner;
    address user1;
    address user2;
    MockERC20 mockERC20;

    function setUp() public {
        untrustedEscrow = new UntrustedEscrow();
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        mockERC20 = new MockERC20();
        assertEq(untrustedEscrow.escrowIdCounter(), 0);
    }

    function testUpdateLockTime() public {
        vm.prank(user1);
        vm.expectRevert();
        untrustedEscrow.updateLockTime(5);

        vm.prank(owner);
        untrustedEscrow.updateLockTime(5);
        assertEq(untrustedEscrow.LOCK_TIME(), 5 days);
    }

    function testDepositFails() public {
        vm.prank(user1);
        vm.expectRevert("Seller address cannot be zero");
        untrustedEscrow.deposit(address(0), address(mockERC20), 1000);

        vm.prank(user1);
        vm.expectRevert("Amount must be greater than zero");
        untrustedEscrow.deposit(user2, address(mockERC20), 0);

        vm.prank(user1);
        vm.expectRevert("Amount must be less than or equal to balance");
        untrustedEscrow.deposit(user2, address(mockERC20), 1);
    }

    function testDeposit() public {
        mockERC20.mint(user1, 1000e18);
        vm.startPrank(user1);
        mockERC20.approve(address(untrustedEscrow), 1000e18);
        uint256 escrowId = untrustedEscrow.deposit(user2, address(mockERC20), 1000e18);
        vm.stopPrank();

        assertEq(untrustedEscrow.escrowIdCounter(), escrowId);
        assertEq(untrustedEscrow.getEscrowDetails(escrowId).buyer, user1);
        assertEq(untrustedEscrow.getEscrowDetails(escrowId).seller, user2);
        assertEq(untrustedEscrow.getEscrowDetails(escrowId).token, address(mockERC20));
        assertEq(untrustedEscrow.getEscrowDetails(escrowId).amount, 1000e18);
        assertEq(untrustedEscrow.getEscrowDetails(escrowId).releaseTime, block.timestamp + 3 days);
        assertEq(untrustedEscrow.getEscrowDetails(escrowId).isActive, true);
        assertEq(mockERC20.balanceOf(address(untrustedEscrow)), 1000e18);
    }

    function testCancel() public {
        mockERC20.mint(user1, 1000e18);
        vm.startPrank(user1);
        mockERC20.approve(address(untrustedEscrow), 1000e18);
        uint256 escrowId = untrustedEscrow.deposit(user2, address(mockERC20), 1000e18);
        vm.expectRevert("Escrow does not exist");
        untrustedEscrow.cancel(escrowId + 10);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("Only buyer can cancel");
        untrustedEscrow.cancel(escrowId);
        vm.stopPrank();

        vm.startPrank(user1);
        untrustedEscrow.cancel(escrowId);
        assertEq(untrustedEscrow.getEscrowDetails(escrowId).isActive, false);
        assertEq(untrustedEscrow.getEscrowDetails(escrowId).amount, 0);
        assertEq(mockERC20.balanceOf(address(untrustedEscrow)), 0);
        assertEq(mockERC20.balanceOf(address(user1)), 1000e18);

        vm.expectRevert("Escrow is no longer active");
        untrustedEscrow.cancel(escrowId);
        vm.stopPrank();
    }

    function testWithdrawFails() public {
        mockERC20.mint(user1, 1000e18);
        vm.startPrank(user1);
        mockERC20.approve(address(untrustedEscrow), 1000e18);
        uint256 escrowId = untrustedEscrow.deposit(user2, address(mockERC20), 1000e18);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("Escrow does not exist");
        untrustedEscrow.withdraw(100);

        vm.expectRevert("Escrow is not yet released");
        untrustedEscrow.withdraw(escrowId);
        vm.stopPrank();

        vm.warp(block.timestamp + 4 days);

        vm.startPrank(user1);
        vm.expectRevert("Only seller can withdraw");
        untrustedEscrow.withdraw(escrowId);
        untrustedEscrow.cancel(escrowId);
        vm.stopPrank();

        vm.startPrank(user2);
        vm.expectRevert("Escrow is no longer active");
        untrustedEscrow.withdraw(escrowId);
        vm.stopPrank();
    }

    function testWithdraw() public {
        mockERC20.mint(user1, 1000e18);
        vm.startPrank(user1);
        mockERC20.approve(address(untrustedEscrow), 1000e18);
        uint256 escrowId = untrustedEscrow.deposit(user2, address(mockERC20), 1000e18);
        vm.stopPrank();

        vm.warp(block.timestamp + 4 days);

        vm.prank(user2);
        untrustedEscrow.withdraw(escrowId);
        vm.stopPrank();

        assertEq(mockERC20.balanceOf(address(user2)), 1000e18);
        assertEq(mockERC20.balanceOf(address(untrustedEscrow)), 0);
        assertEq(untrustedEscrow.getEscrowDetails(escrowId).isActive, false);
        assertEq(untrustedEscrow.getEscrowDetails(escrowId).amount, 0);
    }
}
