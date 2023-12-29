# Fuzzing Write Up

## Ethernaut DEX

### Exploit:
The exploit involves draining all of token1 from the Dex contract by swapping back and forth between `token1` and `token2`. The exploit works because in `getSwapPrice`, the price is calculated based on the current balance of the two tokens in the Dex contract.
```
function getSwapPrice(address from, address to, uint256 amount) public view returns (uint256) {
    return ((amount * IERC20(to).balanceOf(address(this))) / IERC20(from).balanceOf(address(this)));
}
```
Due to the proportional nature of the price calculation, each swap alters the relative prices of the two tokens. So at each round, the token swapped into the Dex contract will have a lower price for subsequent swaps by an increase in its supply Conversely, the token swapped out of the Dex contract will have a higher price for subsequent swaps by a decrease in its supply.

By repeatedly swapping back and forth the two tokens, the attacker can exchange a smaller amount of token1 for a larger amount of token2, and then exchange that larger amount of token2 for an even larger amount of token1. This process repeats until the attacker drains all of token1 from the Dex contract.

### Fuzzer Findings
```
swap(address,address,uint256,uint256): failed!💥  
  Call sequence:
    swap(0x0,0xdeadbeef,357485914,1685423552936879263257937672920722736986340916808832299517876254827585970170)
    swap(0x0,0x0,265319733387905835098571979579112452091016603635355869086970919597176504344,329074713307921204321705673193797570889340766518479129277635436207826133094)
    swap(0x0,0xdeadbeef,1188784517931260770978756393517010561477456211428802631287041595668853417358,18424319158370872478097845649635766964558683789634916327477836444775419151423)
    swap(0x0,0x0,28990067396019192753934556893037859178187241381228388274796966913946951109,1855659393170050857106478203672173958133470007470821677925984161195945249926)
    swap(0x0,0xdeadbeef,22265364589114312960701631308511197334142630208850237850803534153589571136317,7)
    swap(0x0,0x0,50646601937938527101403214713228345209889251461379965581691234127110313819,1502352892136064371487661519994723833384986834024168573490791657199906019320)
    swap(0x0,0xdeadbeef,8459676616857382267516545321318943773174550340661649404381396158787084843906,2139582986129976161128469794507302713776762004693988468443372116281260999773)
    swap(0x0,0x0,13831828604762421754256982427031343613447004518797122589073413850049417444224,21582576249303710216775979901665167326536550664924833196991023113856557293066)
    swap(0x0,0xdeadbeef,3426928688393513918969702889149146091364592431952883321603472719247500442084,69931089164243270651436451935683494175538483814099512658236052563680124616336)
    swap(0x0,0x0,1,3314387000041582849733386286188298871266194009657993527463238894520818)
    swap(0x0,0x0,2526468866181058212863161548680894810488321923703241567221914173828909948,1416627057305073125988599631020839907078416750718290956637251051792665506406)

Event sequence:
Panic(1): Using assert
Approval(2526468866181058212863161548680894810488321923703241567221914173828909948) from: 0x62d69f6867a0a084c6d313943dc22023bc263691
Approval(2526468866181058212863161548680894810488321923703241567221914173828909948) from: 0xee35211c4d9126d520bbfeaf3cfee5fe7b86f221
Transfer(50) from: 0xee35211c4d9126d520bbfeaf3cfee5fe7b86f221
Approval(99) from: 0x62d69f6867a0a084c6d313943dc22023bc263691
Transfer(99) from: 0x62d69f6867a0a084c6d313943dc22023bc263691
LogSwap(@0xee35211C4D9126D520bBfeaf3cFee5FE7B86F221, @0x62d69f6867A0A084C6d313943dC22023Bc263691, 50) from: 0xa329c0648769a73afac7f9381e08fb43dbea72
LogPoolBalance(8, 104) from: 0xa329c0648769a73afac7f9381e08fb43dbea72
LogLiquidity(832) from: 0xa329c0648769a73afac7f9381e08fb43dbea72
LogBalance(102, 6) from: 0xa329c0648769a73afac7f9381e08fb43dbea72


Unique instructions: 2767
Unique codehashes: 3
Corpus size: 1
Seed: 7615146938735840625
```
The invariant I used in the test was:
```
assert(token1.balanceOf(address(this)) < 100 && token2.balanceOf(address(this)) < 100);
```
Where `address(this)` referred to the `TestEthernautDex` contract. The event sequence indicates that when we try to swap 50 `fromTokens` to `toTokens` the invariant was broken, as it resulted in the `TestEthernautDex` contract having more than 100 of `token1`. Since `TestEthernautDex` started with only 10 of each tokens, being able to swap 50 tokens indicates that somehow, the swapping of tokens allowed `TestEthernautDex` to receive additional tokens.

### Other observations:
I was only able to test the `swap` function correctly when the initial supply for `token1` and `token2` was set to `110`. But any other value higher than that would result in Echidna only having 1 swap in its call sequence. For example:
```
token1 = new SwappableToken(address(dexContract), "TokenA", "TKA", 1100);
token2 = new SwappableToken(address(dexContract), "token2", "TKB", 1100);
```
Even running with `--test-limit 100000` and above for instance, mostly returned results similar to the following:
```
swap(address,address,uint256,uint256): failed!💥  
  Call sequence:
    swap(0x0,0x0,18865843821071352508590136157969791365975194551561,3936977094457888908444140558460382350010089717665)

Event sequence:
Panic(1): Using assert
Approval(18865843821071352508590136157969791365975194551561) from: 0x62d69f6867a0a084c6d313943dc22023bc263691
Approval(18865843821071352508590136157969791365975194551561) from: 0xee35211c4d9126d520bbfeaf3cfee5fe7b86f221
Transfer(20) from: 0xee35211c4d9126d520bbfeaf3cfee5fe7b86f221
Approval(20) from: 0x62d69f6867a0a084c6d313943dc22023bc263691
Transfer(20) from: 0x62d69f6867a0a084c6d313943dc22023bc263691
LogSwap(@0xee35211C4D9126D520bBfeaf3cFee5FE7B86F221, @0x62d69f6867A0A084C6d313943dC22023Bc263691, 20) from: 0xa329c0648769a73afac7f9381e08fb43dbea72
LogPoolBalance(80, 120) from: 0xa329c0648769a73afac7f9381e08fb43dbea72
LogLiquidity(9600) from: 0xa329c0648769a73afac7f9381e08fb43dbea72


Unique instructions: 2521
Unique codehashes: 3
Corpus size: 2
Seed: 5462141215965245083
```
As the test runs, the values for `approveAmount` and `amount` would start to shrink but there will still only be one call in the call sequence. My guess is that if the initial supply for both tokens is more than 110, then Echidna might be generating inputs for the fuzzer that, due to the modulo operation and higher token balances, results in swap amounts that are causing this behaviour. 
```
amount = amount % (token1.balanceOf(address(this)) + 1);
```
For example, Echidna could be transfering the unused supply of tokens to `TestEthernautDex`, and this increases its balance of either tokens before `swap` is called. Since the above line is used to restrict the swap amount to the range of 0 to the current token balance, a higher balance results in a higher limit of swap amounts. So this results in swap amounts that are causing a revert because the `dexContract` does not have enough of either Tokens to complete the swap from the get-go.

### Code
```
contract TestEthernautDex {
    address echidna = msg.sender;
    Dex dexContract;
    SwappableToken token1;
    SwappableToken token2;

    event LogSwap(address from, address to, uint256 amount);
    event LogBalance(uint256 token1Balance, uint256 token2Balance);
    event LogPoolBalance(uint256 token1Balance, uint256 token2Balance);
    event LogLiquidity(uint256 liquidity);

    //Set up
    //This contract will be interacting with target contract (dexContract), so it will
    //be msg.sender in the context of the dexContract. It should have some tokens.
    //Echidna will be interacting with this middle contract: TestEthernautDex.
    constructor() {
        dexContract = new Dex();
        token1 = new SwappableToken(address(dexContract), "TokenA", "TKA", 110);
        token2 = new SwappableToken(address(dexContract), "token2", "TKB", 110);

        dexContract.setTokens(address(token1), address(token2));
        dexContract.approve(address(dexContract), 100);

        dexContract.addLiquidity(address(token1), 100);
        dexContract.addLiquidity(address(token2), 100);

        token1.transfer(address(this), 10);
        token2.transfer(address(this), 10);

        dexContract.renounceOwnership();
    }

    function swap(address fromToken, address toToken, uint256 approveAmount, uint256 amount) public {
        //Pre-conditions:
        //  Restrict fuzzer to always use only token1 and token2 addresses
        //  Filter range of input values for `approveAmount` & `amount`
        //  -> `approveAmount` should always be higher than amount
        //  -> `amount` should not exceed the token balance of TestEthernautDex contract
        if (fromToken < toToken) {
            fromToken = address(token1);
            toToken = address(token2);
            amount = amount % (token1.balanceOf(address(this)) + 1);
        } else {
            fromToken = address(token2);
            toToken = address(token1);
            amount = amount % (token2.balanceOf(address(this)) + 1);
        }
        if (approveAmount < amount) {
            // if approve amount less than amount, swap them
            uint256 temp;
            temp = approveAmount;
            approveAmount = amount;
            amount = temp;
        }

        //Actions:
        //  Approve the dexContract to spend the amount of fromToken
        //  Swap fromToken to toToken
        dexContract.approve(address(dexContract), approveAmount);
        dexContract.swap(fromToken, toToken, amount);
        emit LogSwap(fromToken, toToken, amount);

        //Post-conditions:
        //  Check if the pool has a lot less liquidity than expected
        uint256 token1BalanceDex = token1.balanceOf(address(dexContract));
        uint256 token2BalanceDex = token2.balanceOf(address(dexContract));
        emit LogPoolBalance(token1BalanceDex, token2BalanceDex);
        emit LogLiquidity(token1BalanceDex * token2BalanceDex);

        //  Assert that the TestEthernautDex contract cannot have more than 100 of each token,
        //  otherwise it means that there is vulnerability in the dexContract
        emit LogBalance(token1.balanceOf(address(this)), token2.balanceOf(address(this)));
        assert(token1.balanceOf(address(this)) < 100 && token2.balanceOf(address(this)) < 100);
    }
}
```

## Token Whale Challenge
### Modifications:
Since we are using solidity ^0.8.x, an unchecked block was added in the `_transfer` function to mimic what might happen in solidity ^0.4.21, which was what the original contract was written in.
```
function _transfer(address to, uint256 value) internal {
    //added unchecked block to mimic solidity ^0.4.21
    unchecked {
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
    }

    emit Transfer(msg.sender, to, value);
}
```

### Exploit:
The exploit involves underflowing the balance of the player, which is `badPerson1`, during the `transferFrom` call. 
- First `badPerson2` approves `badPerson1` to spend 1000 tokens. 
- Then `badPerson1` transfers 501 tokens to `badPerson2`, leaving `badPerson1` with 499 tokens. 
- Then `badPerson1` calls `transferFrom` to transfer 500 tokens from `badPerson2` to the zero address. 
- When the `_transfer` function is called, the balance of `badPerson1` will be the result of 499 - 500, which underflows to 2^256 - 1. 

This leaves `badPerson1` with a balance of 2^256 - 1.

The root of the exploit lies in the `_transfer` function, where the balance of the sender is not required to be greater than or equal to the value being transferred. If this contract was run in solidity ^0.8.x, the exploit would not work because the `_transfer` function would revert from the underflow.

## Echidna Exercises

### Exercise 3
The initial test fails because the `mint` function takes a `uint256` argument, but in the require statement, the function attempts to cast uint256 to int256, which will always result in failure as it causes an overflow.

Consider the following:
```
  ➜ type(int256).max
  Type: int
  ├ Hex: 0x7fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
  └ Decimal: 57896044618658097711785492504343953926634992332820282019728792003956564819967

  ➜ type(uint256).max
  Type: uint
  ├ Hex: 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
  └ Decimal: 115792089237316195423570985008687907853269984665640564039457584007913129639935
```

When echidna calls `mint` with a uint256 that is larger than `type(int256).max`, such as: `mint(57896044618658097711785492504343953926634992332820282019728792003956564819969)`, this will cause a revert since we are using solidity ^0.8.0 which has overflow/underflow checks.

My suggestion to fix this would be to use uint256 in the constructor for `MintableToken`, for `totalMinted` and `totalMintable` storage variables, and to remove all the casting to int256 in the `mint` function. Since the `balances` mapping is already using uint256, it would make sense to use uint256 for the other variables as well. Additionally, since `mint` will always increase the `totalMinted` variable, it would make sense to use uint256 for this variable as well.

Running echidna with the suggested changes results in passing.

### Exercise 2
When Echidna calls `Owner` and then `resume`, the invariant will break because `Owner` sets msg.sender as the owner of the contract, allowing the contract to be unpaused. For the contract to be unpausable, the contract must have no owner, so we can remove the `Owner` function to achieve this.

### Exercise 4
On checking coverage: (corpus/covered.1703320239.txt)
``````
13 | *r  | contract TestToken is Token {
14 |     |     event LogBalance(uint256 balanceSender, uint256 balanceReceipient);
15 |     |
16 | *   |     function transfer(address to, uint256 value) public override {
17 |     |         // TODO: include `assert(condition)` statements that
18 |     |         // detect a breaking invariant on a transfer.
19 |     |         // Hint: you may use the following to wrap the original function.
20 |     |         //super.transfer(to, value);
21 |     |
22 | *   |         uint256 balanceBeforeSender = balances[msg.sender];
23 | *   |         uint256 balanceBeforeReceipient = balances[to];
24 | *   |         emit LogBalance(balanceBeforeSender, balanceBeforeReceipient);
25 |     |
26 | *   |         super.transfer(to, value);
27 |     |
28 | *   |         uint256 balanceAfterSender = balances[msg.sender];
29 | *   |         uint256 balanceAfterReceipient = balances[to];
30 | *   |         emit LogBalance(balanceAfterSender, balanceAfterReceipient);
31 |     |
32 | *   |         assert(balanceAfterSender <= balanceBeforeSender);
33 | *   |         assert(balanceAfterSender == balanceBeforeSender - value);
34 |     |
35 | *   |         assert(balanceAfterReceipient >= balanceBeforeReceipient);
36 | *   |         assert(balanceAfterReceipient == balanceBeforeReceipient + value);
37 |     |     }
38 |     | }
```
I'm not sure why it shows a revert in line 13 for the TestToken contract.