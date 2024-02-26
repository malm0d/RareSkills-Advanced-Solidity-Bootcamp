// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../../Original/Synthetix/SupportingContracts/RewardsDistributionRecipient.sol";
import "../../Original/Synthetix/SupportingContracts/Pausable.sol";

contract StakingRewardsOptimized is RewardsDistributionRecipient, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    /****************************************************************/
    /*                            Storage                           */
    /****************************************************************/

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

    /****************************************************************/
    /*                            Events                            */
    /****************************************************************/

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint256 newDuration);
    event Recovered(address token, uint256 amount);

    /****************************************************************/
    /*                          Constructor                         */
    /****************************************************************/

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

    /****************************************************************/
    /*                         View Functions                       */
    /****************************************************************/

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function getLastUpdateTime() public view returns (uint256) {
        return timeInfoPacked & ((1 << 128) - 1);
    }

    function getPeriodFinish() public view returns (uint256) {
        return timeInfoPacked >> 128;
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        uint256 periodFinish = getPeriodFinish();
        return block.timestamp < periodFinish ? block.timestamp : periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardsInfo.rewardPerTokenStored;
        }
        RewardsInfo storage _rewardsInfo = rewardsInfo;
        return _rewardsInfo.rewardPerTokenStored + (
            (lastTimeRewardApplicable() - getLastUpdateTime()) * _rewardsInfo.rewardRate * 1e18
        ) / _totalSupply;
    }

    function earned(address account) public view returns (uint256) {
        return (
            (_balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + rewards[account]
        );
    }

    function getRewardForDuration() external view returns (uint256) {
        RewardsInfo storage _rewardsInfo = rewardsInfo;
        return _rewardsInfo.rewardRate * _rewardsInfo.rewardsDuration;
    }
    
    /****************************************************************/
    /*                    External/Public Functions                 */
    /****************************************************************/

    /****************************************************************/
    /*                      Authorized Functions                    */
    /****************************************************************/

    //function notifyRewardAmount(uint256 reward) external override onlyRewardsDistribution updateReward(address(0)) {}

    // Added to support recovering LP Rewards from other systems such as BAL to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner {
        // require(tokenAddress != address(stakingToken), "Cannot withdraw the staking token");
        // IERC20(tokenAddress).safeTransfer(owner, tokenAmount);
        // emit Recovered(tokenAddress, tokenAmount);
    }

    /****************************************************************/
    /*                   Internal/Private Functions                 */
    /****************************************************************/

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
}
