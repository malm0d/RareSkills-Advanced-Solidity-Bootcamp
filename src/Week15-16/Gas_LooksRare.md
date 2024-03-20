## Gas Usage Comparison

### LooksRare: TokenDistributor
Overall gas change: -257298 (-21.753%)

### Diff
```
----------  Gas Savings  ----------
test_firstDeposit() (gas: -4729 (-4.637%)) 
test_calculatePendingRewards() (gas: -9670 (-8.513%)) 
test_withdrawAll() (gas: -22694 (-15.345%)) 
test_withdraw() (gas: -53204 (-26.022%)) 
test_twoDeposits() (gas: -53264 (-26.192%)) 
test_harvestAndCompound() (gas: -53269 (-26.860%)) 
test_updatePool() (gas: -60468 (-28.364%)) 
Overall gas change: -257298 (-21.753%)

----------  Increased usage  ----------
None

```

### Optimized
- `src/Week15-16/Optimized/LooksRare/TokenDistributorOptimized.sol`
```
TokenDistributorTest:test_calculatePendingRewards() (gas: 103921)
TokenDistributorTest:test_firstDeposit() (gas: 97250)
TokenDistributorTest:test_harvestAndCompound() (gas: 145049)
TokenDistributorTest:test_twoDeposits() (gas: 150099)
TokenDistributorTest:test_updatePool() (gas: 152718)
TokenDistributorTest:test_withdraw() (gas: 151256)
TokenDistributorTest:test_withdrawAll() (gas: 125201)
```

### Original
- `src/Week15-16/Original/LooksRare/TokenDistributor.sol`
```
TokenDistributorTest:test_calculatePendingRewards() (gas: 113591)
TokenDistributorTest:test_firstDeposit() (gas: 101979)
TokenDistributorTest:test_harvestAndCompound() (gas: 198318)
TokenDistributorTest:test_twoDeposits() (gas: 203363)
TokenDistributorTest:test_updatePool() (gas: 213186)
TokenDistributorTest:test_withdraw() (gas: 204460)
TokenDistributorTest:test_withdrawAll() (gas: 147895)
```