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
        bool isValid;
    }

    mapping(uint256 => Escrow) public escrows;
    mapping(address => uint256[]) public buyerEscrows;
    mapping(address => uint256[]) public sellerEscrows;

    event EscrowCreated(
        uint256 indexed escrowId,
        address indexed buyer,
        address indexed seller,
        address token,
        uint256 amount,
        uint256 releaseTime,
        bool isValid
    );
    event EscrowReleased(uint256 indexed escrowId);

    constructor() Ownable(msg.sender) {}

    function updateLockTime(uint256 timeInDays) external onlyOwner {
        LOCK_TIME = timeInDays * 1 days;
    }

    function createEscrow(address _seller, address _token, uint256 _amount) external {
        require(_seller != address(0), "Seller address cannot be zero");
        require(_amount > 0, "Amount must be greater than zero");
        require(!(IERC20(_token).balanceOf(msg.sender) < _amount), "Amount must be less than or equal to balance");

        IERC20(_token).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 newEscrowId = escrowIdCounter++;
        uint256 newReleaseTime = block.timestamp + LOCK_TIME;
        escrows[newEscrowId] = Escrow({
            buyer: msg.sender,
            seller: _seller,
            token: _token,
            amount: _amount,
            releaseTime: newReleaseTime,
            isValid: true
        });
        buyerEscrows[msg.sender].push(newEscrowId);
        sellerEscrows[_seller].push(newEscrowId);

        emit EscrowCreated(newEscrowId, msg.sender, _seller, _token, _amount, newReleaseTime, true);
    }

    function releaseEscrow(uint256 escrowId) external {}

    function cancelEscrow(uint256 escrowId) external {}

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
