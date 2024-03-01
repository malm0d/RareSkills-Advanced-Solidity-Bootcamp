// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {StakingRewards} from "src/Week15-16/Original/Synthetix/StakingRewards.sol";
import {StakingRewardsOptimized} from "src/Week15-16/Optimized/Synthetix/StakingRewardsOptimized.sol";

// forge test --mc StakingRewardsTest --gas-report
// forge snapshot --mc StakingRewardsTest --snap <FileName>
// forge snapshot --mc StakingRewardsTest --diff <FileName>
contract StakingRewardsTest is Test {

    MockERC20 stakingToken;
    MockERC20 rewardsToken;
    StakingRewards stakingRewardsOriginal;
    StakingRewardsOptimized stakingRewardsOptimized;

    address owner;
    address rewardsDistributionRecipient;

    function setUp() public {
        owner = address(this);
        rewardsDistributionRecipient = address(0xfeedbeef);

        stakingToken = new MockERC20();
        rewardsToken = new MockERC20();

        stakingRewardsOriginal = new StakingRewards(
            owner, 
            rewardsDistributionRecipient, 
            address(rewardsToken), 
            address(stakingToken)
        );

        stakingRewardsOptimized = new StakingRewardsOptimized(
            owner, 
            rewardsDistributionRecipient, 
            address(rewardsToken), 
            address(stakingToken)
        );

        stakingRewardsOriginal.setRewardsDuration(30 days);
        stakingRewardsOptimized.setRewardsDuration(30 days);

        rewardsToken.transfer(address(stakingRewardsOriginal), 100000000);
        rewardsToken.transfer(address(stakingRewardsOptimized), 100000000);

        vm.warp(100);
        vm.startPrank(rewardsDistributionRecipient);
        stakingRewardsOriginal.notifyRewardAmount(3000000);
        stakingRewardsOptimized.notifyRewardAmount(3000000);
        vm.stopPrank();

        stakingToken.approve(address(stakingRewardsOriginal), 1000000);
        stakingToken.approve(address(stakingRewardsOptimized), 1000000);
        stakingRewardsOriginal.stake(100);
        stakingRewardsOptimized.stake(100);
    }

    //--------------------------------Unit tests for Original--------------------------------

    // function test_rewardsToken() public {
    //     assertEq(address(stakingRewardsOriginal.rewardsToken()), address(rewardsToken));
    // }

    // function test_rewardsDuration() public {
    //     assertEq(stakingRewardsOriginal.rewardsDuration(), 30 days);
    // }

    // function test_lastUpdateTime() public {
    //     assertEq(stakingRewardsOriginal.lastUpdateTime(), 100);
    // }

    // function test_setRewardsDuration() public {
    //     vm.warp(100 days);
    //     stakingRewardsOriginal.setRewardsDuration(60);
    //     assertEq(stakingRewardsOriginal.rewardsDuration(), 60);
    // }

    // function test_recoverERC20() public {
    //     rewardsToken.transfer(address(stakingRewardsOriginal), 100);
    //     uint256 startingBalance = rewardsToken.balanceOf(address(this));
    //     stakingRewardsOriginal.recoverERC20(address(rewardsToken), 100);
    //     assertEq(rewardsToken.balanceOf(address(this)), startingBalance + 100);
    // }

    // function test_recoverERC20_Revert() public {
    //     vm.expectRevert("Cannot withdraw the staking token");
    //     stakingRewardsOriginal.recoverERC20(address(stakingToken), 100);
    // }

    // function test_notifyRewardAmount_First() public {
    //     vm.prank(rewardsDistributionRecipient);
    //     stakingRewardsOriginal.notifyRewardAmount(1000);
    //     assertEq(stakingRewardsOriginal.lastUpdateTime(), block.timestamp);
    //     assertEq(stakingRewardsOriginal.periodFinish(), block.timestamp + 30 days);
    // }

    // function test_notifyRewardAmount_Second() public {
    //     vm.startPrank(rewardsDistributionRecipient);
    //     stakingRewardsOriginal.notifyRewardAmount(1000);
    //     vm.warp(1 days);
    //     stakingRewardsOriginal.notifyRewardAmount(1000);
    //     assertEq(stakingRewardsOriginal.lastUpdateTime(), 1 days);
    //     assertEq(stakingRewardsOriginal.periodFinish(), 1 days + 30 days);
    // }

    // function test_notifyRewardAmount_Revert() public {
    //     vm.prank(rewardsDistributionRecipient);
    //     vm.expectRevert("Provided reward too high");
    //     stakingRewardsOriginal.notifyRewardAmount(1000000000);
    // }

    // function test_stake() public {
    //     stakingRewardsOriginal.stake(1000);
    //     assertEq(stakingRewardsOriginal.balanceOf(address(this)), 1100);
    // }

    // function test_stake_Revert() public {
    //     vm.expectRevert("Cannot stake 0");
    //     stakingRewardsOriginal.stake(0);
    // }

    // function test_withdraw() public {
    //     stakingRewardsOriginal.withdraw(100);
    //     assertEq(stakingRewardsOriginal.balanceOf(address(this)), 0);
    // }

    // function test_withdraw_Revert() public {
    //     vm.expectRevert("Cannot withdraw 0");
    //     stakingRewardsOriginal.withdraw(0);
    // }

    // function test_getReward() public {
    //     vm.warp(10 days);
    //     uint256 rewardsBefore = rewardsToken.balanceOf(address(this));
    //     stakingRewardsOriginal.getReward();
    //     assertTrue(rewardsToken.balanceOf(address(this)) > rewardsBefore);
    // }

    // function test_exit() public {
    //     stakingRewardsOriginal.exit();
    //     assertEq(stakingRewardsOriginal.balanceOf(address(this)), 0);
    // }


    //--------------------------------Unit tests for Optimized--------------------------------

    function test_rewardsToken() public {
        assertEq(stakingRewardsOptimized.rewardsToken(), address(rewardsToken));
    }

    function test_rewardsDuration() public {
        assertEq(stakingRewardsOptimized.rewardsDuration(), 30 days);
    }

    function test_lastUpdateTime() public {
        assertEq(stakingRewardsOptimized.lastUpdateTime(), 100);
    }

    function test_setRewardsDuration() public {
        vm.warp(100 days);
        stakingRewardsOptimized.setRewardsDuration(60);
        assertEq(stakingRewardsOptimized.rewardsDuration(), 60);
    }

    function test_recoverERC20() public {
        rewardsToken.transfer(address(stakingRewardsOptimized), 100);
        uint256 startingBalance = rewardsToken.balanceOf(address(this));
        stakingRewardsOptimized.recoverERC20(address(rewardsToken), 100);
        assertEq(rewardsToken.balanceOf(address(this)), startingBalance + 100);
    }

    function test_recoverERC20_Revert() public {
        vm.expectRevert(bytes4(keccak256("AddressNotAllowed()")));
        stakingRewardsOptimized.recoverERC20(address(stakingToken), 100);
    }

    function test_notifyRewardAmount_First() public {
        vm.prank(rewardsDistributionRecipient);
        stakingRewardsOptimized.notifyRewardAmount(1000);
        assertEq(stakingRewardsOptimized.lastUpdateTime(), block.timestamp);
        assertEq(stakingRewardsOptimized.periodFinish(), block.timestamp + 30 days);
    }

    function test_notifyRewardAmount_Second() public {
        vm.startPrank(rewardsDistributionRecipient);
        stakingRewardsOptimized.notifyRewardAmount(1000);
        vm.warp(1 days);
        stakingRewardsOptimized.notifyRewardAmount(1000);
        assertEq(stakingRewardsOptimized.lastUpdateTime(), 1 days);
        assertEq(stakingRewardsOptimized.periodFinish(), 1 days + 30 days);
    }

    function test_notifyRewardAmount_Revert() public {
        vm.prank(rewardsDistributionRecipient);
        vm.expectRevert(bytes4(keccak256("RewardExceedsBalance()")));
        stakingRewardsOptimized.notifyRewardAmount(1000000000);
    }

    function test_stake() public {
        stakingRewardsOptimized.stake(1000);
        assertEq(stakingRewardsOptimized.balanceOf(address(this)), 1100);
    }

    function test_stake_Revert() public {
        vm.expectRevert(bytes4(keccak256("AmountZero()")));
        stakingRewardsOptimized.stake(0);
    }

    function test_withdraw() public {
        stakingRewardsOptimized.withdraw(100);
        assertEq(stakingRewardsOptimized.balanceOf(address(this)), 0);
    }

    function test_withdraw_Revert() public {
        vm.expectRevert(bytes4(keccak256("AmountZero()")));
        stakingRewardsOptimized.withdraw(0);
    }

    function test_getReward() public {
        vm.warp(10 days);
        uint256 rewardsBefore = rewardsToken.balanceOf(address(this));
        stakingRewardsOptimized.getReward();
        assertTrue(rewardsToken.balanceOf(address(this)) > rewardsBefore);
    }

    function test_exit() public {
        stakingRewardsOptimized.exit();
        assertEq(stakingRewardsOptimized.balanceOf(address(this)), 0);
    }

}