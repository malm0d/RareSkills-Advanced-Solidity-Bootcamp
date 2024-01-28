// SPDX-License-Identifier: MIT
pragma solidity ^0.8.15;

import {Test, console2} from "forge-std/Test.sol";
import {RewardToken, NftToStake, Depositoor, Exploit} from "../../src/Week10-11/RewardToken.sol";

// forge test --match-contract RewardTokenTest -vvvv
contract RewardTokenTest is Test {
    address attackerWallet;
    RewardToken rewardTokenContract;
    NftToStake nftToStakeContract;
    Depositoor depositoorContract;
    Exploit exploitContract;

    function setUp() public {
        attackerWallet = address(0xbad);
        exploitContract = new Exploit();
        nftToStakeContract = new NftToStake(address(exploitContract));
        depositoorContract = new Depositoor(nftToStakeContract);
        rewardTokenContract = new RewardToken(address(depositoorContract));

        depositoorContract.setRewardToken(rewardTokenContract);
    }

    function testExploit() public {
        vm.startPrank(attackerWallet);
        exploitContract.stakeNFT(42, nftToStakeContract, depositoorContract);

        //forward 10 days so in `payout` rewards is 100 ether
        vm.warp(10 days);
        exploitContract.exploit(42, depositoorContract);

        _checkSolved();
    }

    function _checkSolved() internal {
        assertEq(rewardTokenContract.balanceOf(address(exploitContract)), 100 ether);
        assertEq(rewardTokenContract.balanceOf(address(depositoorContract)), 0);
    }
}
