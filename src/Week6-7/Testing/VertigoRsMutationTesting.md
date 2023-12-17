# Mutation Testing (Vertigo-rs)

Link: https://github.com/RareSkills/vertigo-rs

Initially `--sample-ratio 0.1` was used but this only generated five mutations, so another mutation test was run without that argument and the results of that run can be found in `mutation_tests_6`.

For the ERC721/ERC20/Staking application (involving: `SomeNFT.sol`, `Staking.sol` and `RewardToken.sol` in Week2), a total of 57 mutations were generated and the number of mutants killed was **46 / 57**.

## Mutations

### Lived
### 1.
```
Mutation:
    File: /Users/malcolmtan/Projects/RareSkills_Advanced_Solidity/src/Week2/Ecosystem1/SomeNFT.sol
    Line nr: 44
    Result: Lived
    Original line:
             function mintWithDiscount(bytes32[] calldata _proof, uint256 _index) external payable nonReentrant {

    Mutated line:
             function mintWithDiscount(bytes32[] calldata _proof, uint256 _index) external payable  {


Function:
    function mintWithDiscount(bytes32[] calldata _proof, uint256 _index) external payable nonReentrant {
        require(msg.value == MINT_PRICE / DISCOUNT_FACTOR, "Incorrect payment amount");
        require(currentSupply < MAX_SUPPLY, "All tokens have been minted");
        require(!BitMaps.get(addressDiscountedMints, _index), "Already minted with discount");
        _verifyMerkleProof(_proof, msg.sender, _index);

        BitMaps.set(addressDiscountedMints, _index);
        uint256 mintedTokenId = currentSupply;
        //Since we have a max supply, we do not need to worry about overflows
        unchecked {
            currentSupply++;
        }

        _safeMint(msg.sender, mintedTokenId);
        emit MintWithDiscount(msg.sender, mintedTokenId);

        (address receiver, uint256 royaltyAmount) = royaltyInfo(mintedTokenId, MINT_PRICE / DISCOUNT_FACTOR);
        (bool success,) = payable(receiver).call{value: royaltyAmount}("");
        require(success, "Royalties payment failed");
    }
```
The mutation involved removing the `nonReentrant` modifier in the function, and this mutation lived because there was no test in `test/Week2/SomeNft.t.sol` to test for reentrancy with this function. There were other tests for reentrancy for other functions, but for `mintWithDiscount` it was difficult to simulate a reentrancy attack with a malicious contract because the function requires a merkle proof, the use of `msg.sender` and the token id. Additionally, the statement: `require(!BitMaps.get(addressDiscountedMints, _index), "Already minted with discount");` ensures that once a discount is used, it cannot be used again, so a reentrant call attempting to use the same discount would fail this check.

### 2.
```
Mutation:
    File: /Users/malcolmtan/Projects/RareSkills_Advanced_Solidity/src/Week2/Ecosystem1/Staking.sol
    Line nr: 141
    Result: Lived
    Original line:
             function claimRewards(uint256 _tokenId) external nonReentrant whenNotPaused {

    Mutated line:
             function claimRewards(uint256 _tokenId) external  whenNotPaused {

Function:
    function claimRewards(uint256 _tokenId) external nonReentrant whenNotPaused {
        require(getClaimTime(_tokenId) > 0, "This token ID is not staked");
        require(msg.sender == getOriginalOwner(_tokenId), "Only the original owner can claim rewards for this token ID");
        require(!(block.timestamp - getClaimTime(_tokenId) < interval), "Can only claim after every 24 hours");

        //update the claimTime bits to the current timestamp
        stakingInfo[_tokenId] = _packStakingData(msg.sender);
        rewardTokenContract.mintRewards(msg.sender, MINT_AMOUNT);

        emit MintRewards(msg.sender, MINT_AMOUNT);
    }
```
The `claimRewards` function makes an external call to the `rewardTokenContract` which is a trusted contract. In order to test for reentrancy through this function, a malicious reward token can be used to try to reenter this function, however I did not attempt this because I assumed that if the reward token is a trusted contract then there is no reason to test for reentrancy. This mutation was picked up because as there was no test in `test/Week2/Staking.t.sol` to test for the reentrancy. I did try to create a malicious contract to call `claimRewards` twice in a single call, but the function's check for `require(!(block.timestamp - getClaimTime(_tokenId) < interval), "Can only claim after every 24 hours")` ensures that a user can only claim once every 24 hours.

### 3.
```
Mutation:
    File: /Users/malcolmtan/Projects/RareSkills_Advanced_Solidity/src/Week2/Ecosystem1/Staking.sol
    Line nr: 153
    Result: Lived
    Original line:
             function pause() external whenNotPaused onlyOwner {

    Mutated line:
             function pause() external  onlyOwner {
```

### 4.
```
Mutation:
    File: /Users/malcolmtan/Projects/RareSkills_Advanced_Solidity/src/Week2/Ecosystem1/Staking.sol
    Line nr: 157
    Result: Lived
    Original line:
             function unpause() external whenPaused onlyOwner {

    Mutated line:
             function unpause() external  onlyOwner {
```
For the above 2 mutations, I'm not sure why vertigo picked up that these two mutations survived. I had written a test in `test/Week2/Staking.t.sol` to check that when `pause()` is called it would expect to revert when the contract is already paused, and when `unpause()` is called it would expect to revert when the contract is already unpaused:

```
function testPause() public {
        assertEq(stakingContract.paused(), false);

        vm.startPrank(owner);
        stakingContract.pause();
        assertEq(stakingContract.paused(), true);

        vm.expectRevert(bytes4(keccak256(bytes("EnforcedPause()"))));
        stakingContract.pause();

        stakingContract.unpause();
        assertEq(stakingContract.paused(), false);

        vm.expectRevert(bytes4(keccak256(bytes("ExpectedPause()"))));
        stakingContract.unpause();

        vm.stopPrank();
        ...
    }
```

### Error

### 1*.
```
Mutation:
    File: /Users/malcolmtan/Projects/RareSkills_Advanced_Solidity/src/Week2/Ecosystem1/Staking.sol
    Line nr: 35
    Result: Error
    Original line:
             uint256 private constant _BITMASK_ADDRESS = (1 << 160) - 1;

    Mutated line:
             uint256 private constant _BITMASK_ADDRESS = (1 >> 160) - 1;


➜ (1 >> 160) - 1
Type: uint
├ Hex: 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
└ Decimal: 115792089237316195423570985008687907853269984665640564039457584007913129639935
➜ 
➜ type(uint256).max
Type: uint
├ Hex: 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
└ Decimal: 115792089237316195423570985008687907853269984665640564039457584007913129639935

```
When using Chisel to investigate the value of the mutated line, it returned the max value for `uint256`. Assuming that the REPL contract in Chisel does not have underflow(& overflow) protection, this is the expected behavior for `uint256` because in `(1 >> 160) - 1`, the `(1 >> 160)` operation effectively shifts `0x0000000000000000000000000000000000000000000000000000000000000001` by 160 bits to the right, and this results in `0`. The subsequent operation of subtracting `1` would mean that it would underflow and wrap around to the maximum value of `uint256` because `uint256` is an unsigned integer type, and it cannot take `-1`.

In the context of the contract and the tests in `Staking.sol` and `Staking.t.sol`, both are using Solidity 0.8.21 which has underflow and overflow protection, so the mutated line is causing an error as the underflow is causing a revert.

### 2.
```
Mutation:
    File: /Users/malcolmtan/Projects/RareSkills_Advanced_Solidity/src/Week2/Ecosystem1/SomeNFT.sol
    Line nr: 28
    Result: Error
    Original line:
             constructor(bytes32 _merkleRoot, address _royaltyReceiver) ERC721("SomeNFT", "SOME") Ownable(msg.sender) {

    Mutated line:
             constructor(bytes32 _merkleRoot, address _royaltyReceiver)  Ownable(msg.sender) {
```

### 3.
```
Mutation:
    File: /Users/malcolmtan/Projects/RareSkills_Advanced_Solidity/src/Week2/Ecosystem1/SomeNFT.sol
    Line nr: 28
    Result: Error
    Original line:
             constructor(bytes32 _merkleRoot, address _royaltyReceiver) ERC721("SomeNFT", "SOME") Ownable(msg.sender) {

    Mutated line:
             constructor(bytes32 _merkleRoot, address _royaltyReceiver) ERC721("SomeNFT", "SOME")  {
```

### 4.
```
Mutation:
    File: /Users/malcolmtan/Projects/RareSkills_Advanced_Solidity/src/Week2/Ecosystem1/RewardToken.sol
    Line nr: 13
    Result: Error
    Original line:
             constructor() ERC20("RewardToken", "RT") Ownable(msg.sender) {}

    Mutated line:
             constructor()  Ownable(msg.sender) {}
```

### 5.
```
Mutation:
    File: /Users/malcolmtan/Projects/RareSkills_Advanced_Solidity/src/Week2/Ecosystem1/RewardToken.sol
    Line nr: 13
    Result: Error
    Original line:
             constructor() ERC20("RewardToken", "RT") Ownable(msg.sender) {}

    Mutated line:
             constructor() ERC20("RewardToken", "RT")  {}
```

### 6.
```
Mutation:
    File: /Users/malcolmtan/Projects/RareSkills_Advanced_Solidity/src/Week2/Ecosystem1/Staking.sol
    Line nr: 59
    Result: Error
    Original line:
             constructor(address _someNFT, address _rewardToken) Ownable(msg.sender) {

    Mutated line:
             constructor(address _someNFT, address _rewardToken)  {
```

For the above 5 errors, I'm not sure why these are occuring, as I had written tests to enforce their values. It could be the way that I'm testing them thats causing the error but I'm not sure.
```
    //SomeNft.t.sol
    function testNameAndSymbol() public {
        SomeNFT _someNFT = new SomeNFT(merkleRoot, royaltyReceiver);
        assertEq(_someNFT.name(), "SomeNFT");
        assertEq(_someNFT.symbol(), "SOME");
        assertEq(_someNFT.owner(), owner);
        assertEq(_someNFT.merkleRoot(), merkleRoot);
    }

    //Staking.t.sol
    function testNFTNameAndSymbol() public {
        string memory name = someNFT.name();
        string memory symbol = someNFT.symbol();
        address ownr = someNFT.owner();
        bytes32 mrklRt = someNFT.merkleRoot();

        assertEq(name, "SomeNFT");
        assertEq(symbol, "SOME");
        assertEq(ownr, owner);
        assertEq(mrklRt, merkleRoot);
    }

    //Staking.t.sol
    function testTokenInit() public {
        string memory name = rewardToken.name();
        string memory symbol = rewardToken.symbol();
        address ownr = rewardToken.owner();
        uint256 amt = stakingContract.MINT_AMOUNT();

        assertEq(name, "RewardToken");
        assertEq(symbol, "RT");
        assertEq(ownr, owner);
        assertEq(amt, 10 * (10 ** 18));
    }
```

### 7.
```
Mutation:
    File: /Users/malcolmtan/Projects/RareSkills_Advanced_Solidity/src/Week2/Ecosystem1/Staking.sol
    Line nr: 45
    Result: Error
    Original line:
             uint256 public constant MINT_AMOUNT = 10 * (10 ** 18); //10 RTs

    Mutated line:
             uint256 public constant MINT_AMOUNT = 10 / (10 ** 18); //10 RTs
```
Like the first 5 errors, I wrote a test to enfore this amount, but I'm not sure why I'm getting an error:
```
    //Staking.t.sol
    function testTokenInit() public {
        ...
        uint256 amt = stakingContract.MINT_AMOUNT();
        ...
        assertEq(amt, 10 * (10 ** 18));
    }
```

To execute:
- python path-to-this-project/vertigo-rs/vertigo.py run --sample-ratio 0.1 --exclude src/Week1 --exclude src/Week3-5 --output mutation_tests_n
- ... run --exclude src/Week1 --exclude src/Week3-5 --exclude src/Week2/CTFs --exclude src/Week2/Ecosystem2 --output mutation_tests_n