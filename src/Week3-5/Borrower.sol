//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract Borrower is IERC3156FlashBorrower, Ownable2Step, ReentrancyGuard {
    IERC3156FlashLender public lender;
    address public trustedInitiator;

    constructor(address _lender, address _trustedInitiator) Ownable(msg.sender) {
        lender = IERC3156FlashLender(_lender);
        trustedInitiator = _trustedInitiator;
    }

    function updateTrustedInitiator(address _trustedInitiator) external onlyOwner {
        require(_trustedInitiator != address(0), "Borrower: trustedInitiator cannot be the zero address");
        trustedInitiator = _trustedInitiator;
    }

    function updateLender(address _lender) external onlyOwner {
        require(_lender != address(0), "Borrower: lender cannot be the zero address");
        lender = IERC3156FlashLender(_lender);
    }

    /**
     * @dev Receive a flash loan.
     * @param initiator The initiator of the loan.
     * @param token The loan currency.
     * @param amount The amount of tokens lent.
     * @param fee The additional amount of tokens to repay.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
     */
    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    )
        external
        returns (bytes32)
    {
        require(msg.sender == address(lender), "Borrower: Lender is not trusted address");
        require(initiator == trustedInitiator, "Borrower: Initiator is not trusted address");

        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }
}
