// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Token} from "../../src/Week6-7/Fuzzing/Echidna_Ex1.sol";

/// @dev Run the template with
///      ```
///      solc-select use 0.8.0
///      echidna program-analysis/echidna/exercises/exercise1/template.sol
///      ```

//echidna ./test/Week6-7/EchidnaEx1Test.sol --contract TestToken
contract TestToken is Token {
    address echidna = tx.origin;

    constructor() {
        balances[echidna] = 10000;
    }

    function echidna_test_balance() public view returns (bool) {
        // TODO: add the property
        return balances[echidna] <= 10_000;
    }
}

//Addtional notes:
//This is a simple test in Solidity 0.8.0 since there are overflow/underflow checks in the compiler.
//If this were a test in a lower version of Solidity, this test would fail because the `transfer`
//function does not check for overflow/underflow.
