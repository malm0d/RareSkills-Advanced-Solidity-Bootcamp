// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILooksRareToken} from "../../Original/LooksRare/interfaces/ILooksRareToken.sol";

contract TokenDistributorOptimized is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for ILooksRareToken;
    

    //currentPhase can be a smaller uint
    //periodLengthInBlock can be smaller uint (length of staking period in blocks)
    //rewardPerBlockForOthers and rewardPerBlockForStakign can be a smaller uint like uint128
}
