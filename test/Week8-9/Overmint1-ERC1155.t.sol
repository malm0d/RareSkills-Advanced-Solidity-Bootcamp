// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

import {Test, console2} from "forge-std/Test.sol";
import {Overmint1_ERC1155, ExploitContract} from "../../src/Week8-9/Overmint1-ERC1155.sol";

contract Overmint1_ERC1155_Test is Test {
    Overmint1_ERC1155 public overmint1_ERC1155;
    ExploitContract public exploitContract;
    address owner;
    address attackerWallet;

    function setUp() public {
        // Deploy contracts
        overmint1_ERC1155 = new Overmint1_ERC1155();
        exploitContract = new ExploitContract(overmint1_ERC1155);
        owner = address(this);
        attackerWallet = address(0xdead);
    }

    function testExploit() public {
        vm.prank(attackerWallet);
        exploitContract.attack();
        _checkSolved();
    }

    function _checkSolved() internal {
        assertTrue(overmint1_ERC1155.balanceOf(address(attackerWallet), 0) == 5, "Challenge Incomplete");
        assertTrue(vm.getNonce(address(attackerWallet)) < 3, "must exploit in two transactions or less");
    }
}
