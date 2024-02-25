// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../../Original/Synthetix/SupportingContracts/RewardsDistributionRecipient.sol";
import "../../Original/Synthetix/SupportingContracts/Pausable.sol";

contract StakingRewardsOptimized is RewardsDistributionRecipient, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    struct RewardsInfo {
        address rewardsToken;
        uint96 rewardsDuration;
        uint256 rewardRate;
        uint256 rewardPerTokenStored;
    }

    RewardsInfo public rewardsInfo;

    address public stakingToken;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    //[0 - 127] `lastUpdateTime`
    //[128 - 255] `periodFinish`
    uint256 private timeInfoPacked;

    //0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff
    uint256 private constant LOWER_HALF_MASK = (1 << 128) - 1;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    constructor(
        address _owner,
        address _rewardsDistribution,
        address _rewardsToken,
        address _stakingToken
    )
        Owned(_owner)
    {
        rewardsInfo.rewardsToken = _rewardsToken;
        stakingToken = _stakingToken;
        rewardsDistribution = _rewardsDistribution;
    }

    //WIP

    //Function to set both `lastUpdateTime` and `periodFinish` at once
    function _setTimeInfo(uint128 _lastUpdateTime, uint128 _periodFinish) internal {
        timeInfoPacked = (uint256(_periodFinish) << 128) | uint256(_lastUpdateTime);
    }

    function _setLastUpdateTime(uint128 _lastUpdateTime) internal {
        assembly {
            let timeInfoPackedSlot := timeInfoPacked.slot
            let current := sload(timeInfoPackedSlot)
            let mask := not(LOWER_HALF_MASK) //flip the bits in `LOWER_HALF_MASK`
            let clearedLower := and(current, mask)
            sstore(timeInfoPackedSlot, or(clearedLower, _lastUpdateTime))
        }
    }

    function _setPeriodFinish(uint128 _periodFinish) internal {
        assembly {
            let timeInfoPackedSlot := timeInfoPacked.slot
            let current := sload(timeInfoPackedSlot)
            let clearedUpper := and(current, LOWER_HALF_MASK)
            sstore(timeInfoPackedSlot, or(clearedUpper, shl(128, _periodFinish)))
        }
    }

    //function notifyRewardAmount(uint256 reward) external override onlyRewardsDistribution updateReward(address(0)) {}

    function getLastUpdateTime() public view returns (uint256) {
        return timeInfoPacked & ((1 << 128) - 1);
    }

    function getPeriodFinish() public view returns (uint256) {
        return timeInfoPacked >> 128;
    }
}
