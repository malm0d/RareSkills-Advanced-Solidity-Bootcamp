// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {Overmint1} from "../../src/Week2/CTFs/Overmint1.sol";
import {Attack1} from "../../src/Week2/CTFs/Attack1.sol";

//forge test --match-contract Overmint1Test -vvvvv
contract Overmint1Test is Test {
    Overmint1 overmint1;
    Attack1 attack1;
    address owner;
    address user1;
    address user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        overmint1 = new Overmint1();
        attack1 = new Attack1(address(overmint1));
    }

    function testAttack() public {
        attack1.attack();
        assertTrue(overmint1.success(address(attack1)));
    }
}
