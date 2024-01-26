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
