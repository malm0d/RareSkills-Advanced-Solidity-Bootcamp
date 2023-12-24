// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {MintableToken} from "../../src/Week6-7/Fuzzing/Echidna_Ex3.sol";

/// @dev Run the template with
///      ```
///      solc-select use 0.8.0
///      echidna program-analysis/echidna/exercises/exercise3/template.sol --contract TestToken
///      ```

//echidna ./test/Week6-7/EchidnaEx3Test.sol --contract TestToken
contract TestToken is MintableToken {
    address echidna = msg.sender;

    // TODO: update the constructor
    constructor() MintableToken(10_000) {
        owner = echidna;
    }

    function echidna_test_balance() public view returns (bool) {
        // TODO: add the property
        return balances[echidna] <= 10_000;
    }
}

//Addtional notes:
// The initial test fails because the `mint` function takes a `uint256` argument,
// but in the require statement, the function attempts to cast uint256 to int256,
// which will always result in failure as it causes an overflow.
//
// Consider the following:
//
//  ➜ type(int256).max
//  Type: int
//  ├ Hex: 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
//  └ Decimal: 57896044618658097711785492504343953926634992332820282019728792003956564819967
//
//  ➜ type(uint256).max
//  Type: uint
//  ├ Hex: 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
//  └ Decimal: 115792089237316195423570985008687907853269984665640564039457584007913129639935
//
// When echidna calls `mint` with a uint256 that is larger than `type(int256).max`, such as:
// mint(57896044618658097711785492504343953926634992332820282019728792003956564819969), this
// will cause a revert since we are using solidity ^0.8.0 which has overflow/underflow checks.
//
// My suggestion to fix this would be to use uint256 in the constructor for `MintableToken`,
// for `totalMinted` and `totalMintable` storage variables, and to remove all the casting
// to int256 in the `mint` function. Since the `balances` mapping is already using uint256,
// it would make sense to use uint256 for the other variables as well. Additionally, since
// `mint` will always increase the `totalMinted` variable, it would make sense to use
// uint256 for this variable as well.
//
// Running echidna with the suggested changes results in passing.
