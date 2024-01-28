// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import {Test, console2} from "forge-std/Test.sol";
import {VulnerableDeFiContract, ReadOnlyPool, Exploit} from "../../src/Week10-11/ReadOnly.sol";

// forge test --match-contract ReadOnlyTest -vvvv
contract ReadOnlyTest is Test {
    address attackerWallet;
    VulnerableDeFiContract vulnerableDeFiContract;
    ReadOnlyPool readOnlyPoolContract;
    Exploit exploitContract;

    function setUp() public {
        attackerWallet = address(0xbadbad);
        readOnlyPoolContract = new ReadOnlyPool();
        vulnerableDeFiContract = new VulnerableDeFiContract(readOnlyPoolContract);
        exploitContract = new Exploit(readOnlyPoolContract, vulnerableDeFiContract);

        readOnlyPoolContract.addLiquidity{value: 100 ether}();
        readOnlyPoolContract.earnProfit{value: 1 ether}();
        vulnerableDeFiContract.snapshotPrice();

        //Player starts with 2 ETH
        vm.deal(attackerWallet, 2 ether);
    }

    function testExploit() public {
        vm.startPrank(attackerWallet);
        exploitContract.exploit{value: 2 ether}();
        _checkSolved();
    }

    function _checkSolved() internal {
        assertEq(vulnerableDeFiContract.lpTokenPrice(), 0);
    }
}
