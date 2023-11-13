// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {Overmint2} from "../../src/Week2/CTFs/Overmint2.sol";
import {Attack2} from "../../src/Week2/CTFs/Attack2.sol";

//forge test --match-contract Overmint2Test -vvvvv
contract Overmint2Test is Test {
    Overmint2 overmint2;
    Attack2 attack2;
    address owner;
    address user1;
    address user2;

    function setUp() public {
        owner = address(this);
        user1 = address(0x1);
        user2 = address(0x2);
        overmint2 = new Overmint2();
        attack2 = new Attack2(address(overmint2));
    }

    function testAttack() public {
        attack2.attack();
        assertTrue(overmint2.success());
    }
}
