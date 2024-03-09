## Gas Usage Comparison

### TraderJoe: TokenVesting
Overall gas change: -54293 (-9.752%)

### Diff
```
----------  Gas Savings  ----------
test_beneficiary() (gas: 0 (0.000%)) 
test_revocable() (gas: 0 (0.000%)) 
test_duration() (gas: 6 (0.062%)) 
test_cliff() (gas: 18 (0.186%)) 
test_start() (gas: 27 (0.279%)) 
test_released() (gas: -29 (-0.292%)) 
test_revoked() (gas: -47 (-0.471%)) 
test_emergencyRevoke() (gas: -328 (-0.631%)) 
test_emergencyRevoke_revert() (gas: -553 (-1.042%)) 
test_release_revert() (gas: -317 (-1.525%)) 
test_revoke_revert() (gas: -3856 (-6.570%)) 
test_release_one() (gas: -4733 (-7.537%)) 
test_release_two() (gas: -4733 (-7.538%)) 
test_revoke_two() (gas: -8543 (-11.451%)) 
test_revoke_one() (gas: -31205 (-28.970%)) 
Overall gas change: -54293 (-9.752%)

----------  Increased usage  ----------
test_duration() (gas: 6 (0.062%)) 
test_cliff() (gas: 18 (0.186%)) 
test_start() (gas: 27 (0.279%)) 

Overall gas change: -54293 (-9.752%)
```

### Optimized
- `src/Week15-16/Optimized/TraderJoe/TokenVestingOptimized.sol`
```
TokenVestingTest:test_beneficiary() (gas: 7754)
TokenVestingTest:test_cliff() (gas: 9716)
TokenVestingTest:test_duration() (gas: 9642)
TokenVestingTest:test_emergencyRevoke() (gas: 51674)
TokenVestingTest:test_emergencyRevoke_revert() (gas: 52532)
TokenVestingTest:test_release_one() (gas: 58061)
TokenVestingTest:test_release_revert() (gas: 20470)
TokenVestingTest:test_release_two() (gas: 58059)
TokenVestingTest:test_released() (gas: 9889)
TokenVestingTest:test_revocable() (gas: 7625)
TokenVestingTest:test_revoke_one() (gas: 76509)
TokenVestingTest:test_revoke_revert() (gas: 54834)
TokenVestingTest:test_revoke_two() (gas: 66064)
TokenVestingTest:test_revoked() (gas: 9939)
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