// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/console.sol";
import {SanctionToken} from "../../src/Week1/SanctionToken.sol";

//forge test --match-contract SanctionTokenTest -vvvvv
contract SanctionTokenTest is Test {
    SanctionToken sanctionToken;
    address owner;
    address user1;
    address user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        sanctionToken = new SanctionToken(1000000);
        sanctionToken.transfer(user1, 100000);
        sanctionToken.transfer(user2, 100000);
        assertEq(sanctionToken.totalSupply(), 1000000);
        assertEq(sanctionToken.balanceOf(owner), 800000);
        assertEq(sanctionToken.balanceOf(user1), 100000);
        assertEq(sanctionToken.balanceOf(user2), 100000);
    }

    function testOwner() public {
        assertEq(sanctionToken.owner(), owner);
        vm.startPrank(user1);
        vm.expectRevert();
        sanctionToken.banAddress(owner);
        vm.expectRevert();
        sanctionToken.unbanAddress(owner);
    }

    function testSanctionSender() public {
        sanctionToken.banAddress(user1);
        vm.expectRevert("Sender is sanctioned");
        vm.prank(user1);
        sanctionToken.transfer(user2, 1000);
    }

    function testUnsanctionSender() public {
        sanctionToken.banAddress(user1);
        vm.expectRevert("Sender is sanctioned");
        vm.prank(user1);
        sanctionToken.transfer(user2, 1000);

        sanctionToken.unbanAddress(user1);
        vm.prank(user1);
        sanctionToken.transfer(user2, 1);
        assertEq(sanctionToken.balanceOf(user2), 100001);
    }

    function testSanctionReceiver() public {
        sanctionToken.banAddress(user2);
        vm.expectRevert("Recipient is sanctioned");
        vm.prank(user1);
        sanctionToken.transfer(user2, 1000);
        assertEq(sanctionToken.balanceOf(user2), 100000);
    }

    function testMint() public {
        sanctionToken.mint(user1, 1000);
        assertEq(sanctionToken.balanceOf(user1), 101000);
        vm.expectRevert("Cannot mint zero tokens");
        sanctionToken.mint(user1, 0);
    }

    function testBurn() public {
        sanctionToken.burn(user1, 1000);
        assertEq(sanctionToken.balanceOf(user1), 99000);
        vm.expectRevert("Cannot burn zero tokens");
        sanctionToken.burn(user1, 0);
    }
}
