// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test, console2} from "forge-std/Test.sol";
import {Overmint3, Exploit, ExploitMedium} from "../../src/Week10-11/Overmint3.sol";

// forge test --match-contract Overmint3Test -vvvv
contract Overmint3Test is Test {
    Overmint3 overmint3Contract;
    address attackerWallet;
    Exploit exploitContract;

    function setUp() public {
        overmint3Contract = new Overmint3();
        attackerWallet = address(0xbad);
        exploitContract = new Exploit(overmint3Contract, attackerWallet);
    }

    function testExploit() public {
        vm.startPrank(attackerWallet);
        exploitContract.retrieve();
        vm.stopPrank();
        _checkSolved();
    }

    function _checkSolved() internal {
        assertEq(overmint3Contract.balanceOf(attackerWallet), 5);
        assertTrue(vm.getNonce(address(attackerWallet)) <= 1, "must exploit in one transaction");
    }
}
