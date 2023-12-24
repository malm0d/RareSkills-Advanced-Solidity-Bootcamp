// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Token} from "../../src/Week6-7/Fuzzing/Echidna_Ex2.sol";

/// @dev Run the template with
///      ```
///      solc-select use 0.8.0
///      echidna program-analysis/echidna/exercises/exercise2/template.sol
///      ```

//echidna ./test/Week6-7/EchidnaEx2Test.sol --contract TestToken
contract TestToken is Token {
    constructor() {
        pause(); // pause the contract
        owner = address(0); // lose ownership
    }

    function echidna_cannot_be_unpause() public view returns (bool) {
        // TODO: add the property
        return paused() == true;
    }
}

//Addtional notes:
// When Echidna calls `Owner` and then `resume`, the invariant will break because `Owner`
// sets msg.sender as the owner of the contract, allowing the contract to be unpaused.
// For the contract to be unpausable, the contract must have no owner, so we can remove
// the `Owner` function to achieve this.
