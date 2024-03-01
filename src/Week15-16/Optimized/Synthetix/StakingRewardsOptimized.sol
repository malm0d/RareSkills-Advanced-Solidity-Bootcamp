// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../../Original/Synthetix/SupportingContracts/RewardsDistributionRecipient.sol";
import "../../Original/Synthetix/SupportingContracts/Pausable.sol";

contract StakingRewardsOptimized is RewardsDistributionRecipient, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;

    error AddressNotAllowed();
    error IncompleteRewardsPeriod();
    error AmountZero();
    error RewardExceedsBalance();

    /****************************************************************/
    /*                            Storage                           */
    /****************************************************************/

    uint256 public rewardRate;
    uint256 public rewardPerTokenStored;

    //[0 - 159] `rewardsToken` address
    //[160 - 255] `rewardsDuration` uint96
    uint256 tokenAndDuration;

    //[0 - 127] `lastUpdateTime` uint128
    //[128 - 255] `periodFinish` uint128
    uint256 timeInfoPacked;

    address public stakingToken;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    //0x00000000000000000000000000000000ffffffffffffffffffffffffffffffff
    uint256 private constant LOWER_HALF_MASK = (1 << 128) - 1;

    uint256 private constant BITMASK_ADDRESS = (1 << 160) - 1;

    uint256 private _totalSupply;
    mapping(address => uint256) private _balances;

    /****************************************************************/
    /*                            Events                            */
    /****************************************************************/

    event RewardAdded(uint256 reward);
    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardsDurationUpdated(uint96 newDuration);
    event Recovered(address token, uint256 amount);

    /****************************************************************/
    /*                           Modifiers                          */
    /****************************************************************/
    
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        _setLastUpdateTime(uint128(lastTimeRewardApplicable()));
        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
        _;
    }

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
        _setRewardsToken(_rewardsToken);
        stakingToken = _stakingToken;
        rewardsDistribution = _rewardsDistribution;
    }

    /****************************************************************/
    /*                         View Functions                       */
    /****************************************************************/

    function rewardsToken() public view returns (address addr) {
        assembly {
            addr := shr(96, shl(96, sload(tokenAndDuration.slot)))
        }
    }

    function rewardsDuration() public view returns (uint256 dur) {
        assembly {
            dur := shr(160, sload(tokenAndDuration.slot))
        }
    }

    function periodFinish() public view returns (uint256) {
        return timeInfoPacked >> 128;
    }

    function lastUpdateTime() public view returns (uint256 time) {
        return timeInfoPacked & ((1 << 128) - 1);
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) external view returns (uint256) {
        return _balances[account];
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        uint256 _periodFinish = periodFinish();
        return block.timestamp < _periodFinish ? block.timestamp : _periodFinish;
    }

    function rewardPerToken() public view returns (uint256) {
        if (_totalSupply == 0) {
            return rewardPerTokenStored;
        }
        return rewardPerTokenStored + (
            (lastTimeRewardApplicable() - lastUpdateTime()) * rewardRate * 1e18
        ) / _totalSupply;
    }

    function earned(address account) public view returns (uint256) {
        return (
            (_balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + rewards[account]
        );
    }

    function getRewardForDuration() external view returns (uint256) {
        return rewardRate * rewardsDuration();
    }
    
    /****************************************************************/
    /*                    External/Public Functions                 */
    /****************************************************************/

    function stake(uint256 amount) external nonReentrant notPaused updateReward(msg.sender) {
        if (amount == 0) {
            revert AmountZero();
        }
        _totalSupply = _totalSupply + amount;
        _balances[msg.sender] = _balances[msg.sender] + amount;
        IERC20(stakingToken).safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant updateReward(msg.sender) {
        if (amount == 0) {
            revert AmountZero();
        }
        _totalSupply = _totalSupply - amount;
        _balances[msg.sender] = _balances[msg.sender] - amount;
        IERC20(stakingToken).safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant updateReward(msg.sender) {
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            IERC20(rewardsToken()).safeTransfer(msg.sender, reward);
            emit RewardPaid(msg.sender, reward);
        }
    }

    function exit() external {
        withdraw(_balances[msg.sender]);
        getReward();
    }

    /****************************************************************/
    /*                      Authorized Functions                    */
    /****************************************************************/

    function notifyRewardAmount(uint256 reward) external override onlyRewardsDistribution {
        rewardPerTokenStored = rewardPerToken();
        
        uint256 blockTimestamp = block.timestamp;
        uint256 _periodFinish = periodFinish();
        uint256 _rewardsDuration = rewardsDuration();

        if (blockTimestamp >= _periodFinish) {
            rewardRate = reward / _rewardsDuration;
        } else {
            uint256 remaining = _periodFinish - blockTimestamp;
            uint256 leftover = remaining * rewardRate;
            rewardRate = (reward + leftover) / _rewardsDuration;
        }

        uint256 balance = IERC20(rewardsToken()).balanceOf(address(this));
        if (rewardRate > balance / _rewardsDuration) {
            revert RewardExceedsBalance();
        }

        _setTimeInfo(uint128(blockTimestamp), uint128(blockTimestamp + _rewardsDuration));
        emit RewardAdded(reward);
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external payable onlyOwner {
        if (tokenAddress == address(stakingToken)) {
            revert AddressNotAllowed();
        }
        IERC20(tokenAddress).safeTransfer(owner, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setRewardsDuration(uint96 _rewardsDuration) external payable onlyOwner {
        if (block.timestamp <= periodFinish()) {
            revert IncompleteRewardsPeriod();
        }
        _setRewardsDuration(_rewardsDuration);
        emit RewardsDurationUpdated(_rewardsDuration);
    }

    /****************************************************************/
    /*                   Internal/Private Functions                 */
    /****************************************************************/

    function _setRewardsToken(address _rewardsToken) internal {
        assembly {
            let tokenAndDurationSlot := tokenAndDuration.slot
            let current := sload(tokenAndDurationSlot)
            let mask := not(BITMASK_ADDRESS) //flip the bits in `BITMASK_ADDRESS`
            let clearedLower := and(current, mask)
            sstore(tokenAndDurationSlot, or(clearedLower, _rewardsToken))
        }
    }

    function _setRewardsDuration(uint96 _rewardsDuration) internal {
        assembly {
            let tokenAndDurationSlot := tokenAndDuration.slot
            let current := sload(tokenAndDurationSlot)
            let clearedUpper := and(current, BITMASK_ADDRESS)
            sstore(tokenAndDurationSlot, or(clearedUpper, shl(160, _rewardsDuration)))
        }
    }

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

    //Not used in the contract, but included for completeness
    // function _setPeriodFinish(uint128 _periodFinish) internal {
    //     assembly {
    //         let timeInfoPackedSlot := timeInfoPacked.slot
    //         let current := sload(timeInfoPackedSlot)
    //         let clearedUpper := and(current, LOWER_HALF_MASK)
    //         sstore(timeInfoPackedSlot, or(clearedUpper, shl(128, _periodFinish)))
    //     }
    // }
}
