## Gas Usage Comparison

### Synthetix: StakingRewards
Overall gas change: -134837 (-24.258%)

### Diff
```
----------  Gas Savings  ----------
test_rewardsToken() (gas: -11 (-0.112%)) 
test_rewardsDuration() (gas: -19 (-0.250%))  
test_recoverERC20_Revert() (gas: -143 (-0.949%)) 
test_stake() (gas: -5604 (-8.814%)) 
test_withdraw() (gas: -4448 (-10.453%)) 
test_exit() (gas: -4952 (-10.475%)) 
test_getReward() (gas: -25560 (-26.031%)) 
test_notifyRewardAmount_First() (gas: -10313 (-26.987%)) 
test_notifyRewardAmount_Revert() (gas: -13185 (-34.490%)) 
test_notifyRewardAmount_Second() (gas: -30560 (-44.899%)) 
test_stake_Revert() (gas: -20085 (-56.267%)) 
test_withdraw_Revert() (gas: -20030 (-59.649%)) 
Overall gas change: -134837 (-24.258%)

----------  Increased usage  ----------
test_recoverERC20() (gas: 6 (0.020%)) 
test_setRewardsDuration() (gas: 36 (0.183%))
test_lastUpdateTime() (gas: 31 (0.408%))

Overall gas change: -134837 (-24.258%)
```

### Optimized
- `src/Week15-16/Optimized/Synthetix/StakingRewardsOptimized.sol`
```
StakingRewardsTest:test_exit() (gas: 42322)
StakingRewardsTest:test_getReward() (gas: 72629)
StakingRewardsTest:test_lastUpdateTime() (gas: 7624)
StakingRewardsTest:test_notifyRewardAmount_First() (gas: 27902)
StakingRewardsTest:test_notifyRewardAmount_Revert() (gas: 25044)
StakingRewardsTest:test_notifyRewardAmount_Second() (gas: 37504)
StakingRewardsTest:test_recoverERC20() (gas: 30765)
StakingRewardsTest:test_recoverERC20_Revert() (gas: 14928)
StakingRewardsTest:test_rewardsDuration() (gas: 7575)
StakingRewardsTest:test_rewardsToken() (gas: 9800)
StakingRewardsTest:test_setRewardsDuration() (gas: 19672)
StakingRewardsTest:test_stake() (gas: 57977)
StakingRewardsTest:test_stake_Revert() (gas: 15611)
StakingRewardsTest:test_withdraw() (gas: 38104)
StakingRewardsTest:test_withdraw_Revert() (gas: 13550)
```

### Original
- `src/Week15-16/Original/Synthetix/StakingRewards.sol`
```
StakingRewardsTest:test_exit() (gas: 47274)
StakingRewardsTest:test_getReward() (gas: 98189)
StakingRewardsTest:test_lastUpdateTime() (gas: 7593)
StakingRewardsTest:test_notifyRewardAmount_First() (gas: 38215)
StakingRewardsTest:test_notifyRewardAmount_Revert() (gas: 38229)
StakingRewardsTest:test_notifyRewardAmount_Second() (gas: 68064)
StakingRewardsTest:test_recoverERC20() (gas: 30759)
StakingRewardsTest:test_recoverERC20_Revert() (gas: 15071)
StakingRewardsTest:test_rewardsDuration() (gas: 7594)
StakingRewardsTest:test_rewardsToken() (gas: 9811)
StakingRewardsTest:test_setRewardsDuration() (gas: 19636)
StakingRewardsTest:test_stake() (gas: 63581)
StakingRewardsTest:test_stake_Revert() (gas: 35696)
StakingRewardsTest:test_withdraw() (gas: 42552)
StakingRewardsTest:test_withdraw_Revert() (gas: 33580)
```