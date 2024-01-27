// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test, console2} from "forge-std/Test.sol";
import {DeleteUser, Exploit} from "../../src/Week10-11/DeleteUser.sol";

// forge test --match-contract DeleteUserTest -vvvv
contract DeleteUserTest is Test {
    DeleteUser deleteUserContract;
    Exploit exploitContract;
    address attackerWallet;

    function setUp() public {
        deleteUserContract = new DeleteUser();
        attackerWallet = address(0xbadbad);
        exploitContract = new Exploit(deleteUserContract);
        vm.deal(address(deleteUserContract), 1 ether);
        vm.deal(address(exploitContract), 1 ether);
    }

    function testExploit() public {
        vm.startPrank(attackerWallet);
        exploitContract.exploit();
        _checkSolved();
    }

    function _checkSolved() internal {
        assertEq(address(deleteUserContract).balance, 0);
        assertTrue(vm.getNonce(address(attackerWallet)) <= 1, "must exploit in one transaction");
    }
}
