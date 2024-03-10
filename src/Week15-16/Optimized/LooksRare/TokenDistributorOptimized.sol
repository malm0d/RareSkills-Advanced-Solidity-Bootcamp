// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {ILooksRareToken} from "../../Original/LooksRare/interfaces/ILooksRareToken.sol";

// //[0 - 127] (uint128) accTokenPerShare
// //[128 - 175] (uint48) endBlock
// //[176 - 223] (uint48) lastRewardBlock
// //[224 - 255] (uint32) currentPhase
// uint256 private packedAccBlockPhase;

// //[0 - 111] (uint112) totalAmountStaked
// //[112 - 183] (uint72) rewardPerBlockForOthers
// //[184 - 255] (uint72) rewardPerBlockForStaking
// uint256 private packedTotalStakedBlockRewards;

contract TokenDistributorOptimized is ReentrancyGuard {
    using SafeERC20 for IERC20;
    using SafeERC20 for ILooksRareToken;

    /****************************************************************/
    /*                            Storage                           */
    /****************************************************************/

    uint256 private constant _BITMAKS_UINT224 = (1 << 224) - 1;
    uint256 private constant _BITMASK_UINT128 = (1 << 128) - 1;
    uint256 private constant _BITMASK_UINT112 = (1 << 112) - 1;
    uint256 private constant PRECISION_FACTOR = 10 ** 12;

    address public immutable looksRareToken;
    address public immutable tokenSplitter;
    uint256 public immutable NUMBER_PERIODS;
    uint256 public immutable START_BLOCK;

    struct StakingPeriod {
        uint112 rewardPerBlockForStaking;
        uint112 rewardPerBlockForOthers;
        uint32 periodLengthInBlock;
    }

    struct UserInfo {
        uint128 amount; // Amount of staked tokens provided by user
        uint128 rewardDebt; // Reward debt
    }

    //[0 - 127] (uint128) accTokenPerShare
    //[128 - 255] (uint128) totalAmountStaked
    uint256 private packedAccTokenTotalStaked;

    //[0 - 111] (uint112) endBlock
    //[112 - 223] (uint112) lastRewardBlock
    //[224 - 255] (uint32) currentPhase
    uint256 private packedBlockInfo;

    //[0 - 127] (uint128) rewardPerBlockForOthers
    //[128 - 255] (uint128) rewardPerBlockForStaking
    uint256 private packedRewardPerBlock;

    mapping(uint256 => StakingPeriod) public stakingPeriod;

    mapping(address => UserInfo) public userInfo;

    /****************************************************************/
    /*                            Events                            */
    /****************************************************************/

    event Compound(address indexed user, uint256 harvestedAmount);
    event Deposit(address indexed user, uint256 amount, uint256 harvestedAmount);
    event NewRewardsPerBlock(
        uint256 indexed currentPhase,
        uint256 startBlock,
        uint256 rewardPerBlockForStaking,
        uint256 rewardPerBlockForOthers
    );
    event Withdraw(address indexed user, uint256 amount, uint256 harvestedAmount);

    /****************************************************************/
    /*                          Constructor                         */
    /****************************************************************/

    constructor(
        address _looksRareToken,
        address _tokenSplitter,
        uint256 _startBlock,
        uint256 _numberPeriods,
        uint112[] memory _rewardsPerBlockForStaking,
        uint112[] memory _rewardsPerBlockForOthers,
        uint32[] memory _periodLengthInBlock
    ) {
        require(_periodLengthInBlock.length == _numberPeriods, "TokenDistributor: Invalid periodLengthInBlock arra length");
        require(_rewardsPerBlockForStaking.length == _numberPeriods, "TokenDistributor: Invalid rewardPerBlockForStaking array length");
        require(_rewardsPerBlockForOthers.length == _numberPeriods, "TokenDistributor: Invalid rewardPerBlockForOthers array length");
        
        uint256 nonCirculatingSupply = 
            ILooksRareToken(_looksRareToken).SUPPLY_CAP() - 
            ILooksRareToken(_looksRareToken).totalSupply();

        uint256 amountTokensToBeMinted;
        for (uint256 i = 0; i < _numberPeriods; ) {
            unchecked {
                amountTokensToBeMinted += (
                    _rewardsPerBlockForStaking[i] + _rewardsPerBlockForOthers[i]
                ) * _periodLengthInBlock[i];

                stakingPeriod[i] = StakingPeriod({
                    rewardPerBlockForStaking: _rewardsPerBlockForStaking[i],
                    rewardPerBlockForOthers: _rewardsPerBlockForOthers[i],
                    periodLengthInBlock: _periodLengthInBlock[i]
                });

                i++; 
            }
        }
        assembly {
            if sub(amountTokensToBeMinted, nonCirculatingSupply) {
                mstore(0x00, 0x2c6d5a13) //InvalidRewardParameters()
                revert(0x1c, 0x04)
            }
        }

        looksRareToken = _looksRareToken;
        tokenSplitter = _tokenSplitter;
        NUMBER_PERIODS = _numberPeriods;
        START_BLOCK = _startBlock;
        uint112 initialRewardPerBlockForStaking = _rewardsPerBlockForStaking[0];
        uint112 initialRewardPerBlockForOthers = _rewardsPerBlockForOthers[0];
        uint112 initialPeriodLengthInBlock = _periodLengthInBlock[0];
        assembly {
            //rewardPerBlockForStaking = _rewardsPerBlockForStaking[0];
            //rewardPerBlockForOthers = _rewardsPerBlockForOthers[0];
            let _packedRewardPerBlock := or(
                initialRewardPerBlockForOthers,
                shl(128, initialRewardPerBlockForStaking)
            )
            sstore(packedRewardPerBlock.slot, _packedRewardPerBlock)

            //endBlock = _startBlock + _periodLengthInBlock[0];
            //lastRewardBlock = _startBlock;
            let _endBlock := add(_startBlock, initialPeriodLengthInBlock)
            sstore(
                packedBlockInfo.slot,
                or(_endBlock, shl(112, _startBlock)) 
            )
        }
    }

    /****************************************************************/
    /*                         View Functions                       */
    /****************************************************************/

    function accTokenPerShare() public view returns (uint256 acc) {
        assembly {
            acc := and(_BITMASK_UINT128, sload(packedAccTokenTotalStaked.slot))
        }
    }

    function currentPhase() public view returns (uint256 phase) {
        assembly {
            phase := shr(224, sload(packedBlockInfo.slot))
        }
    }

    function endBlock() public view returns (uint256 end) {
        assembly {
            end := and(_BITMASK_UINT112, sload(packedBlockInfo.slot))
        }
    }

    function lastRewardBlock() public view returns (uint256 last) {
        assembly {
            last := and(_BITMASK_UINT112, shr(112, sload(packedBlockInfo.slot)))
        }
    }

    function rewardPerBlockForOthers() public view returns (uint256 reward) {
        assembly {
            reward := and(_BITMASK_UINT128, sload(packedRewardPerBlock.slot))
        }
    }

    function rewardPerBlockForStaking() public view returns (uint256 reward) {
        assembly {
            reward := shr(128, sload(packedRewardPerBlock.slot))
        }
    }

    function totalAmountStaked() public view returns (uint256 total) {
        assembly {
            total := shr(128, sload(packedAccTokenTotalStaked.slot))
        }
    }

    /****************************************************************/
    /*                    External/Public Functions                 */
    /****************************************************************/

    /****************************************************************/
    /*                   Internal/Private Functions                 */
    /****************************************************************/


}
