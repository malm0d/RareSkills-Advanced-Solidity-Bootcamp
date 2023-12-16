// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import {GodToken} from "../../src/Week1/GodModeToken.sol";

//forge test --match-contract GodModeTokenTest -vvvvv
contract GodModeTokenTest is Test {
    GodToken godToken;
    address owner;
    address admin;
    address user1;
    address user2;

    function setUp() public {
        owner = address(this);
        admin = address(0xa0);
        user1 = address(0x1);
        user2 = address(0x2);
        godToken = new GodToken(owner);
        godToken.transfer(user1, 100000e18);
        godToken.transfer(user2, 100000e18);

        assertEq(godToken.totalSupply(), 1000000e18);
        assertEq(godToken.balanceOf(owner), 800000e18);
        assertEq(godToken.balanceOf(user1), 100000e18);
        assertEq(godToken.balanceOf(user2), 100000e18);
        assertEq(godToken.balanceOf(admin), 0);
        assertEq(godToken.iluvatar(), owner);
    }

    function testGodModeTransfer() public {
        godToken.godModeTransfer(user1, user2, 50000e18);
        assertEq(godToken.balanceOf(user1), 50000e18);
        assertEq(godToken.balanceOf(user2), 150000e18);
    }

    function testChange() public {
        godToken.replaceIluvatar(admin);
        assertEq(godToken.iluvatar(), admin);
        vm.prank(admin);
        godToken.godModeTransfer(user1, user2, 50000e18);
        assertEq(godToken.balanceOf(user1), 50000e18);
        assertEq(godToken.balanceOf(user2), 150000e18);
    }

    function testMint() public {
        godToken.mint(user1, 100000e18);
        assertEq(godToken.balanceOf(user1), 200000e18);

        vm.expectRevert("Cannot mint zero tokens");
        godToken.mint(user1, 0);
    }

    function testBurn() public {
        godToken.burn(user1, 100000e18);
        assertEq(godToken.balanceOf(user1), 0);

        vm.expectRevert("Cannot burn zero tokens");
        godToken.burn(user1, 0);
    }

    function testChangeIluvatar() public {
        vm.startPrank(user1);
        vm.expectRevert();
        godToken.replaceIluvatar(user1);
        vm.stopPrank();
        vm.expectRevert("GodToken: iluvatar cannot be the zero address");
        godToken.replaceIluvatar(address(0));
    }
}
