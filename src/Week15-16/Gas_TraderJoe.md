## Gas Usage Comparison

### TraderJoe: TokenVesting
Overall gas change: -22736 (-4.084%)

### Diff
```
----------  Gas Savings  ----------
test_beneficiary() (gas: 0 (0.000%)) 
test_revocable() (gas: 0 (0.000%)) 
test_revoked() (gas: -29 (-0.290%)) 
test_released() (gas: -29 (-0.292%)) 
test_emergencyRevoke() (gas: -226 (-0.435%)) 
test_emergencyRevoke_revert() (gas: -448 (-0.844%)) 
test_revoke_revert() (gas: -706 (-1.203%)) 
test_release_revert() (gas: -349 (-1.679%)) 
test_revoke_two() (gas: -4815 (-6.454%)) 
test_revoke_one() (gas: -7291 (-6.769%)) 
test_release_one() (gas: -4447 (-7.082%)) 
test_release_two() (gas: -4447 (-7.082%)) 
Overall gas change: -22736 (-4.084%)


----------  Increased usage  ----------
test_duration() (gas: 6 (0.062%)) 
test_cliff() (gas: 18 (0.186%)) 
test_start() (gas: 27 (0.279%)) 


Overall gas change: -22736 (-4.084%)
```

### Optimized
- `src/Week15-16/Optimized/TraderJoe/TokenVestingOptimized.sol`
```
TokenVestingTest:test_beneficiary() (gas: 7754)
TokenVestingTest:test_cliff() (gas: 9716)
TokenVestingTest:test_duration() (gas: 9642)
TokenVestingTest:test_emergencyRevoke() (gas: 51776)
TokenVestingTest:test_emergencyRevoke_revert() (gas: 52637)
TokenVestingTest:test_release_one() (gas: 58347)
TokenVestingTest:test_release_revert() (gas: 20438)
TokenVestingTest:test_release_two() (gas: 58345)
TokenVestingTest:test_released() (gas: 9889)
TokenVestingTest:test_revocable() (gas: 7625)
TokenVestingTest:test_revoke_one() (gas: 100423)
TokenVestingTest:test_revoke_revert() (gas: 57984)
TokenVestingTest:test_revoke_two() (gas: 69792)
TokenVestingTest:test_revoked() (gas: 9957)
TokenVestingTest:test_start() (gas: 9694)
```

### Original
- `src/Week15-16/Original/TraderJoe/TokenVesting.sol`
```
TokenVestingTest:test_beneficiary() (gas: 7754)
TokenVestingTest:test_cliff() (gas: 9698)
TokenVestingTest:test_duration() (gas: 9636)
TokenVestingTest:test_emergencyRevoke() (gas: 52002)
TokenVestingTest:test_emergencyRevoke_revert() (gas: 53085)
TokenVestingTest:test_release_one() (gas: 62794)
TokenVestingTest:test_release_revert() (gas: 20787)
TokenVestingTest:test_release_two() (gas: 62792)
TokenVestingTest:test_released() (gas: 9918)
TokenVestingTest:test_revocable() (gas: 7625)
TokenVestingTest:test_revoke_one() (gas: 107714)
TokenVestingTest:test_revoke_revert() (gas: 58690)
TokenVestingTest:test_revoke_two() (gas: 74607)
TokenVestingTest:test_revoked() (gas: 9986)
TokenVestingTest:test_start() (gas: 9667)
```