// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BancorBondingCurve} from "./BancorBondingCurve.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC1363} from "@openzeppelin/contracts/interfaces/IERC1363.sol";
import {IERC1363Receiver} from "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @dev This contract will accept ERC1363 tokens and mint ERC20 tokens in return.
 *
 * The bancor formula for calculating price of a token is:
 * continuousPrice = reserveBalance / (supply * (1 - reserveRatio)^n)
 * where n represents the exponent that determines the shape of the curve.
 * As n increases, the curve becomes more convex.
 *
 * To get a linear curve: y = mx, where x = reserveBalance / supply (input),
 * the reserveRatio should be 50% (1/2), and n = 1. So effectively, we will get:
 * continuousPrice = 2 * (reserveBalance / supply)
 *
 */
contract TokenSaleAndBuyback is BancorBondingCurve, ERC20, IERC1363Receiver, Ownable2Step, ReentrancyGuard {
    using SafeERC20 for ERC20;
    using SafeERC20 for IERC1363;

    address public immutable reserveToken;
    uint256 public reserveRatio;
    uint256 public reserveBalance;
    uint256 public interval;
    mapping(address => uint256) public buyTimestamps;

    event Buy(address indexed to, uint256 amount);
    event Burn(address indexed from, uint256 amount);

    constructor(address _reserveToken) ERC20("ContinuousToken", "CT") Ownable(msg.sender) {
        reserveRatio = 5e5; //500_000 (50%)
        reserveToken = _reserveToken;
        interval = 1 days;
        reserveBalance = 10_000_000_000e18;
        _mint(msg.sender, 2_000_000_000e18);
    }

    function updateInterval(uint256 _days) external onlyOwner {
        require(_days > 0, "Interval must be greater than zero");
        interval = _days * 1 days;
    }

    function updateReserveRatio(uint256 _reserveRatio) external onlyOwner {
        require(_reserveRatio > 0, "Reserve ratio must be greater than zero");
        reserveRatio = _reserveRatio;
    }

    /**
     * @notice ERC1363 transfer callback function for IERC1363Receiver.
     * @param from address of the sender of the ERC1363 token.
     * @dev This function will be called when the ERC1363 token is transferred to this contract.
     * Executes _continuousMint function.
     */
    function onTransferReceived(
        address, /*operator*/
        address from,
        uint256 value,
        bytes calldata /*data*/
    )
        external
        returns (bytes4)
    {
        require(msg.sender == reserveToken, "Only reserve token can call this function");
        _continuousMint(from, value);
        return IERC1363Receiver.onTransferReceived.selector;
    }

    /**
     * @notice Mints the CT tokens to the caller.
     * @param _amount The amount of reserve tokens to exchange for CT tokens.
     */
    function buy(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Cannot mint zero tokens");
        IERC1363(reserveToken).safeTransferFrom(msg.sender, address(this), _amount);
        buyTimestamps[msg.sender] = block.timestamp;

        emit Buy(msg.sender, _amount);
    }

    /**
     * @notice Burns the CT tokens from the caller.
     * @param _amount The amount of CT tokens to burn.
     */
    function burn(uint256 _amount) external nonReentrant {
        require(_amount > 0, "Cannot burn zero tokens");
        require(!(balanceOf(msg.sender) < _amount), "Cannot burn more than balance");
        require(!(block.timestamp - buyTimestamps[msg.sender] < interval), "Must wait for interval to pass");
        _continuousBurn(msg.sender, _amount);

        emit Burn(msg.sender, _amount);
    }

    /**
     * @notice Calculates the price of the CT token in reserve tokens.
     */
    function getContinuousTokenPrice() external view returns (uint256) {
        return reserveBalance / totalSupply() * reserveRatio;
    }

    /**
     * @notice Calculates the amount of CT tokens to return in exchange for the reserve tokens passed in `amount`.
     * @param amount The amount of reserve tokens to exchange for CT tokens.
     */
    function calculateMintAmount(uint256 amount) public view returns (uint256) {
        return calculatePurchaseReturn(totalSupply(), reserveBalance, uint32(reserveRatio), amount);
    }

    /**
     * @notice Calculates the amount of reserve tokens to return in exchange for the CT tokens passed in `amount`.
     * @param amount The amount of CT tokens to exchange for reserve tokens.
     */
    function calculateBurnAmount(uint256 amount) public view returns (uint256) {
        return calculateSaleReturn(totalSupply(), reserveBalance, uint32(reserveRatio), amount);
    }

    /**
     * @dev Calculates the amount of CT tokens to mint based on the reserve tokens passed in `amount` and
     * mints them to the `to` address.
     * @param to The address to mint the CT tokens to.
     * @param amount The amount of reserve tokens to exchange for CT tokens.
     */
    function _continuousMint(address to, uint256 amount) internal {
        uint256 mintAmount = calculateMintAmount(amount);
        _mint(to, mintAmount);
        reserveBalance += amount;
    }

    /**
     * @dev Calculates the amount of reserve tokens to return based on the CT tokens passed in `amount` and
     * burns the CT tokens from the `from` address.
     * @param from The address to burn the CT tokens from and return reserve tokens.
     * @param amount The amount of CT tokens to exchange for reserve tokens.
     */
    function _continuousBurn(address from, uint256 amount) internal {
        uint256 returnAmount = calculateBurnAmount(amount);
        _burn(from, amount);
        reserveBalance -= returnAmount;
        IERC1363(reserveToken).safeTransfer(from, returnAmount);
    }
}
