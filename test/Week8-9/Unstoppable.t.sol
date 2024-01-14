// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {ReceiverUnstoppable} from "../../src/Week8-9/U_ReceiverUnstoppable.sol";
import {UnstoppableVault, DamnValuableToken} from "../../src/Week8-9/U_UnstoppableVault.sol";

//forge test --match-contract UnstoppableTest -vvvv
contract UnstoppableTest is Test {
    uint256 internal constant TOKENS_IN_VAULT = 1_000_000e18;
    uint256 internal constant INITIAL_PLAYER_TOKEN_BALANCE = 100e18;

    UnstoppableVault public vault;
    ReceiverUnstoppable public receiverContract;
    DamnValuableToken public token;

    address deployer;
    address player;
    address someUser;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */
        deployer = address(this);
        player = address(0xdead);
        someUser = address(0xbeef);

        token = new DamnValuableToken();
        vault = new UnstoppableVault(
            token,
            deployer,
            deployer
        );
        assertEq(address(vault.asset()), address(token));

        token.approve(address(vault), TOKENS_IN_VAULT);
        vault.deposit(TOKENS_IN_VAULT, deployer);
        assertEq(token.balanceOf(address(vault)), TOKENS_IN_VAULT);
        assertEq(vault.totalAssets(), TOKENS_IN_VAULT);
        assertEq(vault.totalSupply(), TOKENS_IN_VAULT);
        assertEq(vault.maxFlashLoan(address(token)), TOKENS_IN_VAULT);
        assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT - 1), 0);
        assertEq(vault.flashFee(address(token), TOKENS_IN_VAULT), 50_000e18);

        token.transfer(player, INITIAL_PLAYER_TOKEN_BALANCE);

        //Show it is possible for someUser to take out a flash loan
        vm.startPrank(someUser);
        receiverContract = new ReceiverUnstoppable(address(vault));
        receiverContract.executeFlashLoan(100e18);
        vm.stopPrank();
    }

    function testExploit() public {
        /**
         * EXPLOIT START *
         */
        /**
         * EXPLOIT END *
         */
        vm.expectRevert();
        validation();
        console2.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        // It is no longer possible to execute flash loans
        vm.startPrank(someUser);
        receiverContract.executeFlashLoan(100e18);
        vm.stopPrank();
    }
}
