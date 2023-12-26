// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Dex} from "../../src/Week6-7/Fuzzing/EthernautDex1.sol";
import {SwappableToken} from "../../src/Week6-7/Fuzzing/EthernautDex1.sol";

//echidna ./test/Week6-7/EthernautDex1_Echidna.sol --test-mode assertion --contract TestEthernautDex
//--test-limit 100000 --corpus-dir corpus
contract TestEthernautDex {
    address echidna = msg.sender;
    Dex dexContract;
    SwappableToken token1;
    SwappableToken token2;

    //40% of initial combined liquidity in the pool: ((100 * 100) * 40) / 100
    uint256 constant MIN_COMBINED_LIQUIDIITY = 4_000;

    event LogSwap(address from, address to, uint256 amount);
    event LogPoolBalance(uint256 token1Balance, uint256 token2Balance);
    event LogLiquidity(uint256 liquidity);

    //Set up
    //This contract will be interacting with target contract (dexContract), so it will
    //be msg.sender in the context of the dexContract. It should have some tokens.
    //Echidna will be interacting with this middle contract: TestEthernautDex.
    constructor() {
        dexContract = new Dex();
        token1 = new SwappableToken(address(dexContract), "Token1", "TK1", 1_000_000);
        token2 = new SwappableToken(address(dexContract), "Token2", "TK2", 1_000_000);

        dexContract.setTokens(address(token1), address(token2));
        dexContract.approve(address(dexContract), 1_000_000);

        dexContract.addLiquidity(address(token1), 100);
        dexContract.addLiquidity(address(token2), 100);

        token1.transfer(address(this), 10);
        token2.transfer(address(this), 10);

        dexContract.renounceOwnership();
    }

    function swap(address fromToken, address toToken, uint256 approveAmount, uint256 amount) public {
        //Pre-conditions:
        //  Restrict fuzzer to use only token1 and token2 addresses
        require(
            (fromToken == address(token1) && toToken == address(token2))
                || (fromToken == address(token2) && toToken == address(token1))
        );
        //  Filter range of input values for `approveAmount` & `amount`
        //  -> `approveAmount` should not exceed the balance of fromToken in this contract
        //  -> `amount` should not exceed the `approveAmount` to be used for swapping
        if (fromToken == address(token1)) {
            approveAmount = approveAmount % (token1.balanceOf(address(this)) + 1);
            amount = amount % approveAmount + 1;
        } else {
            approveAmount = approveAmount % (token2.balanceOf(address(this)) + 1);
            amount = amount % approveAmount + 1;
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

        //  Assert that the pool has more than 40% of the initial combined liquidity
        //  If this assertion fails, then the pool has been exploited.
        assert((token1BalanceDex * token2BalanceDex) > MIN_COMBINED_LIQUIDIITY);
    }
}
