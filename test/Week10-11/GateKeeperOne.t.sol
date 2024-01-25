// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {GatekeeperOne, Exploit} from "../../src/Week10-11/GatekeeperOne.sol";

// forge test --match-contract GatekeeperOneTest -vvvv
contract GatekeeperOneTest is Test {
    GatekeeperOne gateKeeperOne;
    address player;
    Exploit exploitContract;

    function setUp() public {
        gateKeeperOne = new GatekeeperOne();
        player = tx.origin;
        exploitContract = new Exploit(gateKeeperOne, player);
    }

    function testExploit() public {
        vm.startPrank(player);
        exploitContract.attack();
        assertEq(gateKeeperOne.entrant(), player);
    }
}

//gateOne:
//require(msg.sender != tx.origin); basically, we just need to call GatekeeperOne.enter() from a contract, so that
//tx.origin is the EOA address, and msg.sender is the contract address.

//gateTwo:
//require(gasleft() % 8191 == 0); we need to call GatekeeperOne.enter() with a gas amount that is a multiple of 8191.
//The `gasleft` function is a global function that returns the remaining gas amount in the current transaction, after
//executing all the opcodes. So we need to call the function with a specific amount of gas such that it will make the
//`gasleft() % 8191 == 0` condition true. It's difficult to guess the precise amount of gas, but we can brute force it.
//The gas used by the `enter` function must be at least 8191 + all the gas needed to execute the opcodes, so we can use a
//loop with a try-catch and a starting base amount of gas (to prevent out of gas revert) and keep incrementing it
//until it works.

//gateThree:
//The first requirement: `uint32(uint64(_gateKey)) == uint16(uint64(_gateKey))`. The right side only takes the least
//significant 16 bits (2 bytes) of _gateKey, and the left side takes the least significant 32 bits (4 bytes) of _gateKey.
//But we need to make sure that the 2 bytes on the right side are the same as the 2 least significant bytes on the left.
//Thus we have to remove the 2 most significant bytes on the left with a bitmask. So for example, to make `0x12345678' equal
//to `0x00005678`, we can do `0x12345678 & 0x0000FFFF`. This will make the left side equal to the right side with the mask of
//`0x0000FFFF`.

//The second requirement: `uint32(uint64(_gateKey)) != uint64(_gateKey)`. The right side will take the least significant 64
//bits (8 bytes) of _gateKey, and the left side will take the least significant 32 bits (4 bytes) of _gateKey. Here we need
//to maintain the first requirement, and also ensure that if a mask is applied here, the value on both sides will be different.
//Using the mask from the first requirement will not work here, because the left side will be equal to the right side.
//So considering that the left only takes the least significant 4 bytes, and the right take the least significant 8 bytes,
//we just need to also preserve the most significant 4 bytes on the value on the right side. Thus, we can use a mask of
//`0xFFFFFFFF0000FFFF` which builds on top of the first mask. So if _gateKey was `0x1234567812345678`, applying this mask will
//make it 0x1234567800005678. So this will make the left side 0x00005678 and the right side will remain as 0x1234567800005678.

//The third requirement: `uint32(uint64(_gateKey)) == uint16(uint160(tx.origin))`. The right side will take the least
//significant 2 bytes of tx.origin, and the left side will take the least significant 4 bytes of _gateKey. We just need to
//apply the `0xFFFFFFFF0000FFFF` mask to the address of tx.origin (the player) converted to a bytes8 type. To covert an
//address to a bytes8 type, we just need to cast it appropriately (an address is a 20 bytes type): address -> uint160 ->
//uint64 -> bytes8. This would be: bytes8(uint64(uint160(address(player)))) & 0xFFFFFFFF0000FFFF

//Keep in mind that bytes types are left aligned, and numeric types are right aligned. Something like casting bytes8 to uint64
//is akin to converting the bytes8 value to a uint64 value, and vice versa.
//
//address(0x9AebA12E57837B35cb322E857A8114792248f1B9) ->                  0x9AebA12E57837B35cb322E857A8114792248f1B9
//uint160(address(0x9AebA12E57837B35cb322E857A8114792248f1B9)) ->         0x0000000000000000000000009aeba12e57837b35cb322e857a8114792248f1b9
//uint64(uint160(address(0x9AebA12E57837B35cb322E857A8114792248f1B9))) -> 0x0000000000000000000000000000000000000000000000007a8114792248f1b9
//bytes8(uint64(uint160(address(0x9AebA12E57837B35cb322E857A8114792248f1B9)))) -> 0x7a8114792248f1b9
//0x7a8114792248f1b9 & 0xFFFFFFFF0000FFFF ->                                      0x7a8114790000f1b9
//uint64(0x7a8114790000f1b9) ->                                           0x0000000000000000000000000000000000000000000000007a8114790000f1b9
//uint32(uint64(0x7a8114790000f1b9)) ->                                   0x000000000000000000000000000000000000000000000000000000000000f1b9
//uint16(uint160(0x9AebA12E57837B35cb322E857A8114792248f1B9)) ->          0x000000000000000000000000000000000000000000000000000000000000f1b9
