// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {PredictTheFuture, ExploitContract} from "../../src/Week8-9/PredictTheFuture.sol";

//forge test --match-contract PredictTheFutureTest -vvvv
contract PredictTheFutureTest is Test {
    PredictTheFuture public predictTheFuture;
    ExploitContract public exploitContract;

    function setUp() public {
        // Deploy contracts
        predictTheFuture = (new PredictTheFuture){value: 1 ether}();
        exploitContract = new ExploitContract(predictTheFuture);
    }

    function testGuess() public {
        // Set block number and timestamp
        // Use vm.roll() and vm.warp() to change the block.number and block.timestamp respectively
        vm.roll(104293);
        vm.warp(93582192);

        // Put your solution here:
        vm.deal(address(exploitContract), 1 ether);
        exploitContract.lockInGuess(0);

        vm.roll(104295);

        while (!predictTheFuture.isComplete()) {
            try exploitContract.attack() {
                break;
            } catch {
                vm.roll(block.number + 1);
            }
        }

        _checkSolved();
    }

    function _checkSolved() internal {
        assertTrue(predictTheFuture.isComplete(), "Challenge Incomplete");
    }

    receive() external payable {}
}
