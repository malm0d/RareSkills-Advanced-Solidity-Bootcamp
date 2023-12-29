// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Dex} from "../../src/Week6-7/Fuzzing/EthernautDex1.sol";
import {SwappableToken} from "../../src/Week6-7/Fuzzing/EthernautDex1.sol";
import {Test, console2} from "forge-std/Test.sol";

//echidna ./test/Week6-7/EthernautDex1_Echidna.sol --test-mode assertion --contract TestEthernautDex
//--test-limit 100000 --corpus-dir corpus
contract TestEthernautDex {
    address echidna = msg.sender;
    Dex dexContract;
    SwappableToken token1;
    SwappableToken token2;

    // struct State {
    //     address from;
    //     address to;
    //     uint256 amount;
    // }

    // State[] states;
    //event Log(address from, address to, uint256 amount);

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

        // // You can use this to record state snapshots for echidna
        // State memory state = State(fromToken, toToken, amount);
        // states.push(state);
        // for (uint256 i = 0; i < states.length; i++) {
        //     emit Log(states[i].from, states[i].to, states[i].amount);
        // }

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
