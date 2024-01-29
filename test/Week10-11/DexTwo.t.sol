// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {DexTwo, SwappableTokenTwo, Exploit} from "../../src/Week10-11/DexTwo.sol";

// This level will ask you to break DexTwo, a subtlely modified Dex contract
// from the previous level, in a different way. You need to drain all balances
// of token1 and token2 from the DexTwo contract to succeed in this level.
// You will still start with 10 tokens of token1 and 10 of token2. The DEX
// contract still starts with 100 of each token.

// forge test --match-contract DexTwoTest -vvvv
contract DexTwoTest is Test {
    DexTwo dexTwoContract;
    SwappableTokenTwo token1;
    SwappableTokenTwo token2;

    Exploit exploitContract;
    address attackerWallet;

    function setUp() public {
        //Deploy
        dexTwoContract = new DexTwo();
        token1 = new SwappableTokenTwo(address(dexTwoContract), "token1", "tk1", 110);
        token2 = new SwappableTokenTwo(address(dexTwoContract), "token2", "tk2", 110);
        //Set up DexTwo
        dexTwoContract.setTokens(address(token1), address(token2));
        dexTwoContract.approve(address(dexTwoContract), 100);
        dexTwoContract.add_liquidity(address(token1), 100);
        dexTwoContract.add_liquidity(address(token2), 100);
        //Transfer to attacker to start
        attackerWallet = address(0xbeef);
        token1.transfer(attackerWallet, 10);
        token2.transfer(attackerWallet, 10);
        //Deploy exploit contract
        exploitContract = new Exploit();
    }

    function testExploit() public {
        vm.startPrank(attackerWallet);
        exploitContract.exploit(dexTwoContract, token1, token2);
        _checkSolved();
    }

    function _checkSolved() internal {
        assertEq(token1.balanceOf(address(dexTwoContract)), 0);
        assertEq(token2.balanceOf(address(dexTwoContract)), 0);
    }
}
