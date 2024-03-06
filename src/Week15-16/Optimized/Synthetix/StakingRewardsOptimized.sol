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


    //[0 - 207] `rewardRate` uint208
    //[208 - 255] `rewardsDuration` uint48
    uint256 private rewardRateDuration;

    //[0 - 159] rewardPerTokenStored uint160
    //[160 - 207] lastUpdateTime uint48
    //[208 - 255] periodFinish uint48
    uint256 private rewardTimeInfoPacked;

    address public rewardsToken;
    address public stakingToken;

    mapping(address => uint256) public userRewardPerTokenPaid;
    mapping(address => uint256) public rewards;

    //0x000000000000ffffffffffffffffffffffffffffffffffffffffffffffffffff
    uint256 private constant _BITMASK_UINT208 = (1 << 208) - 1;

    //0x000000000000000000000000ffffffffffffffffffffffffffffffffffffffff
    uint256 private constant _BITMASK_UINT160 = (1 << 160) - 1;

    //0x0000000000000000000000000000000000000000ffffffffffffffffffffffff
    uint256 private constant _BITMASK_UINT96 = (1 << 96) - 1;

    //0x0000000000000000000000000000000000000000000000000000ffffffffffff
    uint256 private constant _BITMASK_UINT48 = (1 << 48) - 1;

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
        rewardsToken = _rewardsToken;
        stakingToken = _stakingToken;
        rewardsDistribution = _rewardsDistribution;
    }

    /****************************************************************/
    /*                         View Functions                       */
    /****************************************************************/

    function rewardRate() public view returns (uint256 rate) {
        assembly {
            rate := shr(48, shl(48, sload(rewardRateDuration.slot)))
        }
    }

    function rewardPerTokenStored() public view returns (uint256 stored) {
        assembly {
            stored := shr(96, shl(96, sload(rewardTimeInfoPacked.slot)))
        }
    }

    function lastUpdateTime() public view returns (uint256 time) {
        assembly {
            time := and(_BITMASK_UINT48, shr(160, sload(rewardTimeInfoPacked.slot)))
        }
    }

    function periodFinish() public view returns (uint256 pf) {
        assembly {
            pf := shr(208, sload(rewardTimeInfoPacked.slot))
        }
    }

    function rewardsDuration() public view returns (uint256 dur) {
        assembly {
            dur := shr(208, sload(rewardTimeInfoPacked.slot))
        }
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
            return rewardPerTokenStored();
        }
        uint256 _rewardTimeInfoPacked = rewardTimeInfoPacked;
        uint256 _rewardPerTokenStored;
        uint256 _periodFinish;
        uint256 _lastUpdateTime;
        uint256 _rewardRate;
        assembly {
            _rewardPerTokenStored := shr(96, shl(96, _rewardTimeInfoPacked))
            _periodFinish := shr(208, _rewardTimeInfoPacked)
            _lastUpdateTime := and(_BITMASK_UINT48, shr(160, _rewardTimeInfoPacked))
            _rewardRate := shr(48, shl(48, sload(rewardRateDuration.slot)))
        }

        _periodFinish = block.timestamp < _periodFinish ? block.timestamp : _periodFinish;

        return _rewardPerTokenStored + ((_periodFinish - _lastUpdateTime) * _rewardRate * 1e18) / _totalSupply;
    }

    function earned(address account) public view returns (uint256) {
        return (
            (_balances[account] * (rewardPerToken() - userRewardPerTokenPaid[account])) / 1e18 + rewards[account]
        );
    }

    function getRewardForDuration() external view returns (uint256 res) {
        uint256 _rewardRateDuration = rewardRateDuration;
        assembly {
            let _rewardRate := shr(48, shl(48, _rewardRateDuration))
            let _rewardsDuration := shr(208, _rewardRateDuration)
            res := mul(_rewardRate, _rewardsDuration)
        }
    }
    
    /****************************************************************/
    /*                    External/Public Functions                 */
    /****************************************************************/

    function stake(uint256 amount) external nonReentrant notPaused {
        if (amount == 0) {
            revert AmountZero();
        }

        _updateReward(msg.sender);

        _totalSupply = _totalSupply + amount;
        _balances[msg.sender] = _balances[msg.sender] + amount;
        IERC20(stakingToken).safeTransferFrom(msg.sender, address(this), amount);
        emit Staked(msg.sender, amount);
    }

    function withdraw(uint256 amount) public nonReentrant {
        if (amount == 0) {
            revert AmountZero();
        }

        _updateReward(msg.sender);

        _totalSupply = _totalSupply - amount;
        _balances[msg.sender] = _balances[msg.sender] - amount;
        IERC20(stakingToken).safeTransfer(msg.sender, amount);
        emit Withdrawn(msg.sender, amount);
    }

    function getReward() public nonReentrant {
        _updateReward(msg.sender);
        uint256 reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            IERC20(rewardsToken).safeTransfer(msg.sender, reward);
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

    function notifyRewardAmount(uint256 _reward) external override onlyRewardsDistribution {
        uint256 _blockTimestamp = block.timestamp;

        uint256 _rewardTimeInfoPacked = rewardTimeInfoPacked;
        uint256 _rewardRateDuration = rewardRateDuration;

        uint256 _rewardPerTokenStored;
        uint256 _periodFinish;
        uint256 _rewardsDuration;
        uint256 _rewardRate;
        assembly {
            _rewardPerTokenStored := shr(96, shl(96, _rewardTimeInfoPacked))
            _periodFinish := shr(208, _rewardTimeInfoPacked)
            _rewardsDuration := shr(208, _rewardRateDuration)
            _rewardRate := shr(48, shl(48, _rewardRateDuration))
        }

        unchecked {
            if (_blockTimestamp >= _periodFinish) {
                _rewardRate = _reward / _rewardsDuration;
            } else {
                uint256 _remaining = _periodFinish - _blockTimestamp;
                uint256 _leftover = _remaining * _rewardRate;
                _rewardRate = (_reward + _leftover) / _rewardsDuration;
            }

            uint256 _balance = IERC20(rewardsToken).balanceOf(address(this));
            if (_rewardRate > _balance / _rewardsDuration) {
                revert RewardExceedsBalance();
            }
        }

        assembly {
            //update rewardRate in rewardRateDuration
            let _rewardRateDurationClearedLower := and(not(_BITMASK_UINT208), _rewardRateDuration)
            let _updatedRewardRateDuration := or(_rewardRateDurationClearedLower, _rewardRate)
            sstore(rewardRateDuration.slot, _updatedRewardRateDuration)

            //update lastUpdateTime and periodFinish in rewardTimeInfoPacked
            let _lastUpdateTime := shl(160, _blockTimestamp)
            _periodFinish := shl(208, add(_blockTimestamp, _rewardsDuration))
            let _rewardTimeInfoPackedClearedUpper := and(_BITMASK_UINT160, _rewardTimeInfoPacked)
            sstore(rewardTimeInfoPacked.slot, or(_rewardTimeInfoPackedClearedUpper, or(_lastUpdateTime, _periodFinish)))
        }

        emit RewardAdded(_reward);
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external payable onlyOwner {
        if (tokenAddress == address(stakingToken)) {
            revert AddressNotAllowed();
        }
        IERC20(tokenAddress).safeTransfer(owner, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setRewardsDuration(uint48 _rewardsDuration) external payable onlyOwner {
        if (block.timestamp <= periodFinish()) {
            revert IncompleteRewardsPeriod();
        }
        assembly {
            let slot := rewardRateDuration.slot
            let rewardRateDurationClearedUpper := and(_BITMASK_UINT208, sload(slot))
            sstore(slot, or(rewardRateDurationClearedUpper, shl(208, _rewardsDuration)))
        }
        emit RewardsDurationUpdated(_rewardsDuration);
    }

    /****************************************************************/
    /*                   Internal/Private Functions                 */
    /****************************************************************/
    
    function _updateReward(address account) internal {
        uint256 _rewardTimeInfoPacked = rewardTimeInfoPacked;
        uint256 _updatedRewardPerToken;

        if (_totalSupply == 0) {
            assembly {
                _updatedRewardPerToken := shr(96, shl(96, _rewardTimeInfoPacked))
            }
        } else {
            uint256 _rewardPerTokenStored;
            uint256 _periodFinish;
            uint256 _lastUpdateTime;
            uint256 _rewardRate;
            assembly {
                _rewardPerTokenStored := shr(96, shl(96, _rewardTimeInfoPacked))
                _periodFinish := shr(208, _rewardTimeInfoPacked)
                _lastUpdateTime := and(_BITMASK_UINT48, shr(160, _rewardTimeInfoPacked))
                _rewardRate := shr(48, shl(48, sload(rewardRateDuration.slot)))
            }

            _periodFinish = block.timestamp < _periodFinish ? block.timestamp : _periodFinish;

            _updatedRewardPerToken = _rewardPerTokenStored + (
                (_periodFinish - _lastUpdateTime) * _rewardRate * 1e18
            ) / _totalSupply;
        }
        //update rewardPerToken with _updatedRewardPerToken
        //update lastUpdateTime with _periodFinish
        assembly {

        }
        // rewards[account] = earned(account);
        // userRewardPerTokenPaid[account] = rewardPerTokenStored;
        // _;

    }
}
