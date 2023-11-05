// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract UntrustedEscrow is Ownable2Step {
    using SafeERC20 for IERC20;
    using Math for uint256;

    uint256 public LOCK_TIME = 3 days;
    uint256 public escrowIdCounter;

    struct Escrow {
        address buyer;
        address seller;
        address token;
        uint256 amount;
        uint256 releaseTime;
        bool isActive;
    }

    mapping(uint256 => Escrow) public escrows;
    mapping(address => uint256[]) public buyerEscrows;
    mapping(address => uint256[]) public sellerEscrows;

    event Deposit(
        uint256 indexed escrowId,
        address indexed buyer,
        address indexed seller,
        address token,
        uint256 amount,
        uint256 releaseTime,
        bool isActive
    );
    event Withdraw(uint256 indexed escrowId);
    event Cancel(uint256 indexed escrowId);

    constructor() Ownable(msg.sender) {}

    function updateLockTime(uint256 timeInDays) external onlyOwner {
        LOCK_TIME = timeInDays * 1 days;
    }

    function deposit(address _seller, address _token, uint256 _amount) external returns (uint256) {
        require(_seller != address(0), "Seller address cannot be zero");
        require(_amount > 0, "Amount must be greater than zero");
        require(!(IERC20(_token).balanceOf(msg.sender) < _amount), "Amount must be less than or equal to balance");

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 newEscrowId = escrowIdCounter + 1;
        uint256 newReleaseTime = block.timestamp + LOCK_TIME;
        escrows[newEscrowId] = Escrow({
            buyer: msg.sender,
            seller: _seller,
            token: _token,
            amount: _amount,
            releaseTime: newReleaseTime,
            isActive: true
        });
        escrowIdCounter = newEscrowId;
        buyerEscrows[msg.sender].push(newEscrowId);
        sellerEscrows[_seller].push(newEscrowId);

        emit Deposit(newEscrowId, msg.sender, _seller, _token, _amount, newReleaseTime, true);
        return newEscrowId;
    }

    function withdraw(uint256 escrowId) external {
        require(!(escrowId > escrowIdCounter), "Escrow does not exist");
        Escrow memory escrow = escrows[escrowId];
        require(escrow.isActive, "Escrow is no longer active");
        require(escrow.releaseTime < block.timestamp, "Escrow is not yet released");
        require(msg.sender == escrow.seller, "Only seller can withdraw");

        uint256 transferAmount = escrow.amount;
        escrow.amount = 0;
        escrow.isActive = false;
        IERC20(escrow.token).safeTransfer(msg.sender, transferAmount);

        emit Withdraw(escrowId);
    }

    function cancel(uint256 escrowId) external {
        require(!(escrowId > escrowIdCounter), "Escrow does not exist");
        Escrow memory escrow = escrows[escrowId];
        require(escrow.isActive, "Escrow is no longer active");
        require(msg.sender == escrow.buyer, "Only buyer can cancel");
        escrow.isActive = false;

        emit Cancel(escrowId);
    }

    function getEscrowDetails(uint256 escrowId) external view returns (Escrow memory) {
        return escrows[escrowId];
    }

    function getBuyerEscrows(address buyer) external view returns (uint256[] memory) {
        return buyerEscrows[buyer];
    }

    function getSellerEscrows(address seller) external view returns (uint256[] memory) {
        return sellerEscrows[seller];
    }
}
