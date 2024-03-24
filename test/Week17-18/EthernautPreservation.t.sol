// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {Preservation, LibraryContract, AttackPreservation} from "src/Week17-18/EthernautPreservation.sol";

//forge test --mc EthernautPreservationTest -vvvv
contract EthernautPreservationTest is Test {
    Preservation preservation;
    LibraryContract timeZone1Library;
    LibraryContract timeZone2Library;
    AttackPreservation attackPreservation;

    address owner;
    address attacker;

    function setUp() public {}

    function testExploit() public {}
}
