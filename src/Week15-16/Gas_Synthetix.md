## Gas Usage Comparison

### Synthetix: StakingRewards
Overall gas change: -26567 (-4.780%).

### Diff
```
----------  Gas Savings  ----------
test_recoverERC20() (gas: -2 (-0.007%)) 
test_rewardsToken() (gas: -17 (-0.173%)) 
test_recoverERC20_Revert() (gas: -143 (-0.949%)) 
test_getReward() (gas: -1803 (-1.836%)) 
test_stake() (gas: -1771 (-2.785%)) 
test_exit() (gas: -1330 (-2.813%)) 
test_withdraw() (gas: -1416 (-3.328%)) 
test_stake_Revert() (gas: -1814 (-5.082%)) 
test_withdraw_Revert() (gas: -1803 (-5.369%)) 
test_notifyRewardAmount_Second() (gas: -7700 (-11.313%)) 
test_notifyRewardAmount_First() (gas: -4430 (-11.592%)) 
test_notifyRewardAmount_Revert() (gas: -4437 (-11.606%))

----------  Increased usage  ----------
test_setRewardsDuration() (gas: 37 (0.188%)) 
test_rewardsDuration() (gas: 25 (0.329%)) 
test_lastUpdateTime() (gas: 37 (0.487%)) 


Overall gas change: -26567 (-4.780%)
```

### Optimized
- `src/Week15-16/Optimized/Synthetix/StakingRewards.sol`
```
StakingRewardsTest:test_exit() (gas: 45944)
StakingRewardsTest:test_getReward() (gas: 96386)
StakingRewardsTest:test_lastUpdateTime() (gas: 7630)
StakingRewardsTest:test_notifyRewardAmount_First() (gas: 33785)
StakingRewardsTest:test_notifyRewardAmount_Revert() (gas: 33792)
StakingRewardsTest:test_notifyRewardAmount_Second() (gas: 60364)
StakingRewardsTest:test_recoverERC20() (gas: 30757)
StakingRewardsTest:test_recoverERC20_Revert() (gas: 14928)
StakingRewardsTest:test_rewardsDuration() (gas: 7619)
StakingRewardsTest:test_rewardsToken() (gas: 9794)
StakingRewardsTest:test_setRewardsDuration() (gas: 19673)
StakingRewardsTest:test_stake() (gas: 61810)
StakingRewardsTest:test_stake_Revert() (gas: 33882)
StakingRewardsTest:test_withdraw() (gas: 41136)
StakingRewardsTest:test_withdraw_Revert() (gas: 31777)
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