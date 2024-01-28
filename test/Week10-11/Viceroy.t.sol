// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test, console2} from "forge-std/Test.sol";
import {OligarchyNFT, Governance, CommunityWallet, ExploitMain} from "../../src/Week10-11/Viceroy.sol";

// forge test --match-contract ViceroyTest -vvvv
contract ViceroyTest is Test {
    address attackerWallet;
    ExploitMain exploitContract;
    Governance governanceContract;
    OligarchyNFT oligarchyNFTContract;
    CommunityWallet communityWalletContract;

    function setUp() public {
        attackerWallet = address(0xbadbad);
        exploitContract = new ExploitMain();

        oligarchyNFTContract = new OligarchyNFT(address(exploitContract));
        governanceContract = new Governance{value: 10 ether}(oligarchyNFTContract);

        communityWalletContract = governanceContract.communityWallet();
        assertEq(address(communityWalletContract).balance, 10 ether);
    }

    function testExploit() public {
        vm.startPrank(attackerWallet);
        exploitContract.exploit(governanceContract, attackerWallet);
        _checkSolved();
    }

    function _checkSolved() internal {
        assertEq(address(communityWalletContract).balance, 0);
        assertGe(attackerWallet.balance, 10 ether);
        assertTrue(vm.getNonce(address(attackerWallet)) <= 2, "must exploit in two transactions");
    }
}
