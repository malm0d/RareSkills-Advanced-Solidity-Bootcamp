// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import "../../src/Week10-11/NaiveReceiver/NaiveFlashLoanReceiver.sol";
import "../../src/Week10-11/NaiveReceiver/NaiveReceiverLenderPool.sol";

//There’s a pool with 1000 ETH in balance, offering flash loans. It has a fixed fee of 1 ETH.
//A user has deployed a contract with 10 ETH in balance. It’s capable of interacting with the
//pool and receiving flash loans of ETH.
//Take all ETH out of the user’s contract. If possible, in a single transaction.

// forge test --match-contract NaiveReceiverTest -vvvv
contract NaiveReceiverTest is Test {
    NaiveReceiverLenderPool naiveReceiverLenderPoolContract;
    FlashLoanReceiver flashLoanReceiverContract;
    Exploit exploitContract;
    address player;
    address ETH;
    uint256 constant ETHER_IN_POOL = 1000 ether;
    uint256 constant ETHER_IN_RECEIVER = 10 ether;

    function setUp() public {
        player = address(0xdead);
        naiveReceiverLenderPoolContract = new NaiveReceiverLenderPool();
        vm.deal(address(naiveReceiverLenderPoolContract), ETHER_IN_POOL);
        ETH = naiveReceiverLenderPoolContract.ETH();
        assertEq(address(naiveReceiverLenderPoolContract).balance, ETHER_IN_POOL);
        assertEq(naiveReceiverLenderPoolContract.maxFlashLoan(ETH), ETHER_IN_POOL);
        assertEq(naiveReceiverLenderPoolContract.flashFee(ETH, 0), 1 ether);

        flashLoanReceiverContract = new FlashLoanReceiver(address(naiveReceiverLenderPoolContract));
        vm.deal(address(flashLoanReceiverContract), ETHER_IN_RECEIVER);

        vm.expectRevert();
        flashLoanReceiverContract.onFlashLoan(address(this), ETH, ETHER_IN_RECEIVER, 1 ether, "0x");
        assertEq(address(flashLoanReceiverContract).balance, ETHER_IN_RECEIVER);

        exploitContract = new Exploit();
    }

    function testExploit() public {
        vm.startPrank(player);
        exploitContract.exploit(flashLoanReceiverContract, naiveReceiverLenderPoolContract, ETH);
        _checkSolved();
    }

    function _checkSolved() internal {
        //Assert all ETH has been drained from the receiver
        assertEq(address(flashLoanReceiverContract).balance, 0);
        assertEq(address(naiveReceiverLenderPoolContract).balance, ETHER_IN_POOL + ETHER_IN_RECEIVER);
    }
}
