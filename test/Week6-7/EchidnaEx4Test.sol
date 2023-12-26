// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Token} from "../../src/Week6-7/Fuzzing/Echidna_Ex4.sol";

/// @dev Run the template with
///      ```
///      solc-select use 0.8.0
///      echidna program-analysis/echidna/exercises/exercise4/template.sol --contract TestToken --test-mode assertion
///      ```

//echidna ./test/Week6-7/EchidnaEx4Test.sol --test-mode assertion --contract TestToken --corpus-dir corpus
contract TestToken is Token {
    event LogBalance(uint256 balanceSender, uint256 balanceReceipient);

    function transfer(address to, uint256 value) public override {
        // TODO: include `assert(condition)` statements that
        // detect a breaking invariant on a transfer.
        // Hint: you may use the following to wrap the original function.
        //super.transfer(to, value);

        uint256 balanceBeforeSender = balances[msg.sender];
        uint256 balanceBeforeReceipient = balances[to];
        emit LogBalance(balanceBeforeSender, balanceBeforeReceipient);

        super.transfer(to, value);

        uint256 balanceAfterSender = balances[msg.sender];
        uint256 balanceAfterReceipient = balances[to];
        emit LogBalance(balanceAfterSender, balanceAfterReceipient);

        assert(balanceAfterSender <= balanceBeforeSender);
        assert(balanceAfterSender == balanceBeforeSender - value);

        assert(balanceAfterReceipient >= balanceBeforeReceipient);
        assert(balanceAfterReceipient == balanceBeforeReceipient + value);
    }
}

//Addtional notes:
// On checking coverage: (corpus/covered.1703320239.txt)
//
//  13 | *r  | contract TestToken is Token {
//  14 |     |     event LogBalance(uint256 balanceSender, uint256 balanceReceipient);
//  15 |     |
//  16 | *   |     function transfer(address to, uint256 value) public override {
//  17 |     |         // TODO: include `assert(condition)` statements that
//  18 |     |         // detect a breaking invariant on a transfer.
//  19 |     |         // Hint: you may use the following to wrap the original function.
//  20 |     |         //super.transfer(to, value);
//  21 |     |
//  22 | *   |         uint256 balanceBeforeSender = balances[msg.sender];
//  23 | *   |         uint256 balanceBeforeReceipient = balances[to];
//  24 | *   |         emit LogBalance(balanceBeforeSender, balanceBeforeReceipient);
//  25 |     |
//  26 | *   |         super.transfer(to, value);
//  27 |     |
//  28 | *   |         uint256 balanceAfterSender = balances[msg.sender];
//  29 | *   |         uint256 balanceAfterReceipient = balances[to];
//  30 | *   |         emit LogBalance(balanceAfterSender, balanceAfterReceipient);
//  31 |     |
//  32 | *   |         assert(balanceAfterSender <= balanceBeforeSender);
//  33 | *   |         assert(balanceAfterSender == balanceBeforeSender - value);
//  34 |     |
//  35 | *   |         assert(balanceAfterReceipient >= balanceBeforeReceipient);
//  36 | *   |         assert(balanceAfterReceipient == balanceBeforeReceipient + value);
//  37 |     |     }
//  38 |     | }
//
// I'm not sure why it shows a revert in line 13 for the TestToken contract.
