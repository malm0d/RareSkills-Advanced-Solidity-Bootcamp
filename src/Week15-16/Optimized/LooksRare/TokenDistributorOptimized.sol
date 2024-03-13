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

    function calculatePendingRewards(address _user) external view returns (uint256 pending) {
        uint256 _NUMBER_PERIODS = NUMBER_PERIODS;
        assembly {
            mstore(0x00, shr(96, shl(96, _user)))
            mstore(0x20, userInfo.slot)
            let _userInfo := sload(keccak256(0x00, 0x40))
            let _userAmount := and(_BITMASK_UINT128, _userInfo)
            let _userRewardDebt := shr(128, _userInfo)

            let _blockNumber := number()
            let _packedAccTokenTotalStaked := sload(packedAccTokenTotalStaked.slot)
            let _packedBlockInfo := sload(packedBlockInfo.slot)
            let _totalAmountStaked := shr(128, _packedAccTokenTotalStaked)
            let _lastRewardBlock := and(_BITMASK_UINT112, shr(112, _packedBlockInfo))
            let _accTokenPerShare := and(_BITMASK_UINT128, _packedAccTokenTotalStaked)

            if and(gt(_blockNumber, _lastRewardBlock), gt(_totalAmountStaked, 0)) {
                let _endBlock := and(_BITMASK_UINT112, _packedBlockInfo)
                let _rewardPerBlockForStaking := shr(128, sload(packedRewardPerBlock.slot))

                let multiplier := 0
                //if (blockNumber <= endBlock)
                if iszero(gt(_blockNumber, _endBlock)) {
                    multiplier := sub(_blockNumber, _lastRewardBlock)
                }
                //else: _blockNumber > _endBlock & _lastRewardBlock < _endBlock
                if gt(_blockNumber, _endBlock) {
                    if lt(_lastRewardBlock, _endBlock) {
                        multiplier := sub(_endBlock, _lastRewardBlock)
                    }
                }
                //if above two conditions dont satisfy, we get the (from >= endBlock) condition
                //which returns multiplier as 0.

                let _tokenRewardForStaking := mul(multiplier, _rewardPerBlockForStaking)
                let adjustedCurrentPhase := shr(224, _packedBlockInfo)
                
                //while ((block.number > _endBlock) && (adjustedCurrentPhase < (NUMBER_PERIODS - 1)))
                for {} and(gt(_blockNumber, _endBlock), lt(adjustedCurrentPhase, sub(_NUMBER_PERIODS, 1))) {} {
                    //Update current phase
                    adjustedCurrentPhase := add(adjustedCurrentPhase, 1)

                    mstore(0x00, adjustedCurrentPhase)
                    mstore(0x20, stakingPeriod.slot)
                    let _stakingPeriodLoc := keccak256(0x00, 0x40)
                    let _stakingPeriod := sload(_stakingPeriodLoc)
                    let _stakingPeriodRewardPerBlockForStaking := and(_BITMASK_UINT112, _stakingPeriod)

                    let prevEndBlock := _endBlock
                    let _stakingPeriodPeriodLengthInBlock := shr(224, _stakingPeriod)
                    _endBlock := add(prevEndBlock, _stakingPeriodPeriodLengthInBlock)

                    //Calculate new multiplier
                    let newMultiplier := 0
                    if iszero(gt(_blockNumber, _endBlock)) {
                        newMultiplier := sub(_blockNumber, prevEndBlock)
                    }
                    if gt(_blockNumber, _endBlock) {
                        newMultiplier := _stakingPeriodPeriodLengthInBlock
                    }

                    //Adjust the reward for staking
                    _tokenRewardForStaking := add(
                        _tokenRewardForStaking,
                        mul(newMultiplier, _stakingPeriodRewardPerBlockForStaking)
                    )
                }
                let adjustedTokenPerShare := add(
                    _accTokenPerShare,
                    div(
                        mul(_tokenRewardForStaking, PRECISION_FACTOR),
                        _totalAmountStaked
                    )
                )
                pending := sub(div(mul(_userAmount, adjustedTokenPerShare), PRECISION_FACTOR), _userRewardDebt)
            }

            pending := sub(div(mul(_userAmount, _accTokenPerShare), PRECISION_FACTOR), _userRewardDebt)
        }
    }

    /****************************************************************/
    /*                    External/Public Functions                 */
    /****************************************************************/

    function updatePool() external nonReentrant {
        _updatePool();
    }

    function deposit(uint256 amount) external nonReentrant {
        assembly {
            if iszero(gt(amount, 0)) {
                mstore(0x00, 0x20)
                mstore(0x20, 0x1b)
                mstore(0x40, 0x4465706f7369743a20416d6f756e74206d757374206265203e20300000000000)
                revert(0x00, 0x60) // "Deposit: Amount must be > 0"
            }
        }

        uint256 _packedAccTokenTotalStaked = _updatePool();
    }

    function harvestAndCompound() external nonReentrant {
        uint256 _packedAccTokenTotalStaked = _updatePool();

    }

    function withdraw(uint256 amount) external nonReentrant {
        assembly {

        }

        uint256 _packedAccTokenTotalStaked = _updatePool();
    }

    function withdrawAll() external nonReentrant {
        assembly {
            if iszero(gt(amount, 0)) {
                mstore(0x00, 0x20)
                mstore(0x20, 0x1c)
                mstore(0x40, 0x57697468647261773a20416d6f756e74206d757374206265203e203000000000)
                revert(0x00, 0x60) // "Withdraw: Amount must be > 0"
            }
        }

        uint256 _packedAccTokenTotalStaked = _updatePool();
    }
    

    /****************************************************************/
    /*                   Internal/Private Functions                 */
    /****************************************************************/

    function _updatePool() internal returns (uint256 _packedAccTokenTotalStaked) {
        uint256 blockNumber = block.number;
        uint256 _packedBlockInfo = packedBlockInfo;
        uint256 lastRewardBlock = _BITMASK_UINT112 & (_packedBlockInfo >> 112);
        if (blockNumber <= lastRewardBlock) {
            return;
        }

        _packedAccTokenTotalStaked = packedAccTokenTotalStaked;
        uint256 totalAmountStaked = _packedAccTokenTotalStaked >> 128;
        if (totalAmountStaked == 0) {
            assembly {
                lastRewardBlock := shl(112, blockNumber)
                let clearedUpper := and(_BITMASK_UINT112, _packedBlockInfo)
                let clearedLower := and(not(_BITMASK_UINT224), _packedBlockInfo)
                let cleared := or(clearedUpper, clearedLower)
                sstore(packedBlockInfo.slot, or(lastRewardBlock, cleared))
            }
            return;
        }

        address _looksRareToken = looksRareToken;
        address _tokenSplitter = tokenSplitter;
        uint256 _NUMBER_PERIODS = NUMBER_PERIODS;
        assembly {
            let fmp := mload(0x40)
            let endBlock := and(_BITMASK_UINT112, _packedBlockInfo)
            let multiplier := 0
                //if (blockNumber <= endBlock)
                if iszero(gt(blockNumber, endBlock)) {
                    multiplier := sub(blockNumber, lastRewardBlock)
                }
                //else: blockNumber > endBlock & lastRewardBlock < endBlock
                if gt(blockNumber, endBlock) {
                    if lt(lastRewardBlock, endBlock) {
                        multiplier := sub(endBlock, lastRewardBlock)
                    }
                }
                //if above two conditions dont satisfy, we get the (from >= endBlock) condition
                //which returns multiplier as 0.

            let _packedRewardPerBlock := sload(packedRewardPerBlock.slot)
            let rewardPerBlockForOthers := and(_BITMASK_UINT128, _packedRewardPerBlock)
            let rewardPerBlockForStaking := shr(128, _packedRewardPerBlock)
            let tokenRewardForStaking := mul(multiplier, rewardPerBlockForStaking)
            let tokenRewardForOthers := mul(multiplier, rewardPerBlockForOthers)

            let currentPhase := shr(224, _packedBlockInfo)
            let _stakingPeriodRewardPerBlockForStaking := 0
            let _stakingPeriodRewardPerBlockForOthers := 0
            //while ((block.number > endBlock) && (currentPhase < (NUMBER_PERIODS - 1)))
            for {} and(gt(blockNumber, endBlock), lt(currentPhase, sub(_NUMBER_PERIODS, 1))) {} {
                //Update current phase (packedBlockInfo)
                currentPhase := add(currentPhase, 1)

                //Update rewards per block (packedRewardPerBlock)
                mstore(0x00, currentPhase)
                mstore(0x20, stakingPeriod.slot)
                let _stakingPeriodLoc := keccak256(0x00, 0x40)
                let _stakingPeriod := sload(_stakingPeriodLoc)
                _stakingPeriodRewardPerBlockForStaking := and(_BITMASK_UINT112, _stakingPeriod)
                _stakingPeriodRewardPerBlockForOthers := and(_BITMASK_UINT112, shr(112, _stakingPeriod))

                //emit NewRewardsPerBlock(uint256,uint256,uint256,uint256)
                mstore(0x00, endBlock)
                mstore(0x20, _stakingPeriodRewardPerBlockForStaking)
                mstore(0x40, _stakingPeriodRewardPerBlockForOthers)
                log2(0x00, 0x60, 0x40181eb77bccfdef1a73b669bb4290d98e2fbec678c7cf4578ae256210420e17, currentPhase)

                //Update endBlock (packedBlockInfo)
                let previousEndBlock := endBlock
                endBlock := add(endBlock, shr(224, _stakingPeriod))

                //Calculate new multiplier
                let newMultiplier := 0
                if iszero(gt(blockNumber, endBlock)) {
                    newMultiplier := sub(blockNumber, previousEndBlock)
                }
                if gt(blockNumber, endBlock) {
                    if lt(previousEndBlock, endBlock) {
                        newMultiplier := sub(endBlock, previousEndBlock)
                    }
                }

                //Adjust the reward for staking
                tokenRewardForStaking := add(
                    tokenRewardForStaking,
                    mul(newMultiplier, _stakingPeriodRewardPerBlockForStaking)
                )
                tokenRewardForOthers := add(
                    tokenRewardForOthers,
                    mul(newMultiplier, _stakingPeriodRewardPerBlockForOthers)
                )
            }

            //Update storage after loop
            sstore(
                packedRewardPerBlock.slot,
                or(_stakingPeriodRewardPerBlockForOthers, shl(128, _stakingPeriodRewardPerBlockForStaking))
            )

            //Update values for endBlock and lastRewardBlock
            let _updatedPackedBlockInfo := or(shl(224, currentPhase), and(_BITMAKS_UINT224, _packedBlockInfo))
            _updatedPackedBlockInfo := or(endBlock, and(not(_BITMASK_UINT112), _updatedPackedBlockInfo))

            // Mint tokens only if token rewards for staking are not null
            if gt(tokenRewardForStaking, 0) {
                mstore(0x00, 0x40c10f19) //mint(address,uint256)
                mstore(0x20, address())
                mstore(0x40, tokenRewardForStaking)
                if iszero(call(gas(), _looksRareToken, 0, 0x1c, 0x44, 0x00, 0x20)) {
                    revert(0x00, 0x00)
                }
                let mintStatus := mload(0x00)
                if mintStatus {
                    let accTokenPerShare := and(_BITMASK_UINT128, _packedAccTokenTotalStaked)
                    accTokenPerShare := add(
                        accTokenPerShare,
                        div(mul(tokenRewardForStaking, PRECISION_FACTOR), totalAmountStaked)
                    )
                    _packedAccTokenTotalStaked := or(accTokenPerShare, shl(128, totalAmountStaked))
                    sstore(packedAccTokenTotalStaked.slot, _packedAccTokenTotalStaked)
                }
                mstore(0x00, 0x40c10f19) //mint(address,uint256)
                mstore(0x20, _tokenSplitter)
                mstore(0x40, tokenRewardForOthers)
                if iszero(call(gas(), _looksRareToken, 0, 0x1c, 0x44, 0x00, 0x20)) {
                    revert(0x00, 0x00)
                }
            }

            // Update last reward block only if it wasn't updated after or at the end block
            if iszero(gt(lastRewardBlock, endBlock)) {
                lastRewardBlock := shl(112, blockNumber)
                let clearedUpper := and(_BITMASK_UINT112, _updatedPackedBlockInfo)
                let clearedLower := and(not(_BITMASK_UINT224), _updatedPackedBlockInfo)
                let cleared := or(clearedUpper, clearedLower)
                _updatedPackedBlockInfo := or(lastRewardBlock, cleared)
            }
            sstore(packedBlockInfo.slot, _updatedPackedBlockInfo)

            mstore(0x40, fmp)
        }
    }
}
