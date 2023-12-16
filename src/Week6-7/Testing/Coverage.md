# Coverage on ERC721/ERC20/Staking Application

| File                                       | % Lines           | % Statements      | % Branches       | % Funcs         |
|--------------------------------------------|-------------------|-------------------|------------------|-----------------|
| src/Week2/Ecosystem1/RewardToken.sol       | 100.00% (4/4)     | 100.00% (4/4)     | 100.00% (4/4)    | 100.00% (2/2)   |
| src/Week2/Ecosystem1/SomeNFT.sol           | 100.00% (26/26)   | 100.00% (33/33)   | 94.44% (17/18)   | 100.00% (5/5)   |
| src/Week2/Ecosystem1/Staking.sol           | 100.00% (24/24)   | 100.00% (25/25)   | 91.67% (11/12)   | 100.00% (8/8)   |

In `SomeNFT.sol` I suspect that the branch I did not cover was testing `mintWithDiscount` when the `require(currentSupply < MAX_SUPPLY, "All tokens have been minted");` fails. One practical way to test this is to reduce the `MAX_SUPPLY` to a manageable number, otherwise to test this without changing any code in the contract, I have to generate merkle proofs for 1000 addresses, execute `mintWithDiscount` for all theses addresses, and then try to call a `mintWithDiscount` again.

In `Staking.sol` I think the branch I was not able to cover is the `nonReentrant` modifier for the `claimRewards` function. I wrote a test in `Staking.t.sol` using a malicious `IERC721Receiver` to try to reenter the `claimRewards` function. However, the I think the only way to test the `nonReentrant` modifier in this case would be if the `rewardTokenContract` itself is malicious. But this would not be realistic (I think) because the `rewardTokenContract` should be a trusted contract in the system.