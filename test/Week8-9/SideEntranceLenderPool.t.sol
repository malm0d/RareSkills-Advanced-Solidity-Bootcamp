// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {IFlashLoanEtherReceiver} from "../../src/Week8-9/SideEntranceLenderPool.sol";
import {SideEntranceLenderPool, Exploit} from "../../src/Week8-9/SideEntranceLenderPool.sol";

//forge test --match-contract SideEntranceTest -vvvv

// A surprisingly simple pool allows anyone to deposit ETH, and withdraw it at any point in time.
// It has (starts with) 1000 ETH in balance already, and is offering free flash loans using the
// deposited ETH to promote their system.
// Starting with 1 ETH in balance, pass the challenge by taking all ETH from the pool.
contract SideEntranceTest is Test {
    SideEntranceLenderPool pool;
    Exploit exploitContract;
    address owner;
    address attacker;

    function setUp() public {
        pool = new SideEntranceLenderPool();
        exploitContract = new Exploit(pool);
        owner = address(this);
        attacker = address(0xdead);

        vm.deal(address(pool), 1_000 ether);
        vm.deal(address(attacker), 1 ether);
    }

    function testExploit() public {
        vm.startPrank(attacker);
        exploitContract.exploit();

        _checkSolved();
    }

    function _checkSolved() internal {
        assertTrue(address(pool).balance == 0, "Challenge Incomplete");
    }
}
