// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {LooksRareToken} from "src/Week15-16/Original/LooksRare/LooksRareToken.sol";
import {TokenDistributor} from "src/Week15-16/Original/LooksRare/TokenDistributor.sol";
import {TokenDistributorOptimized} from "src/Week15-16/Optimized/LooksRare/TokenDistributorOptimized.sol";

// forge test --mc TokenDistributorTest --via-ir --gas-report / -vvvv
// forge snapshot --mc TokenDistributorTest --via-ir --snap <FileName>
// forge snapshot --mc TokenDistributorTest --via-ir --diff <FileName>
contract TokenDistributorTest is Test {
    MockERC20 mockErc20Token;
    LooksRareToken looksRareToken1;
    LooksRareToken looksRareToken2;
    TokenDistributor tokenDistributorOriginal;
    TokenDistributorOptimized tokenDistributorOptimized;

    address owner;
    address tokenSplitter;
    uint256 startBlock;
    uint256[] rewardsPerBlockForStaking1;
    uint256[] rewardsPerBlockForOthers1;
    uint256[] periodLengthsInBlocks1;
    uint256 numberPeriods;

    uint112[] rewardsPerBlockForStaking2;
    uint112[] rewardsPerBlockForOthers2;
    uint32[] periodLengthsInBlocks2;

    function setUp() public {
        owner = address(this);
        tokenSplitter = address(0xbad);
        startBlock = 100;
        rewardsPerBlockForStaking1 = [1000 ether, 1000 ether];
        rewardsPerBlockForOthers1 = [500 ether, 500 ether];
        periodLengthsInBlocks1 = [10, 10];
        rewardsPerBlockForStaking2 = [1000 ether, 1000 ether];
        rewardsPerBlockForOthers2 = [500 ether, 500 ether];
        periodLengthsInBlocks2 = [10, 10];
        numberPeriods = 2;

        mockErc20Token = new MockERC20();
        looksRareToken1 = new LooksRareToken(
            address(this),
            999970000 ether,
            1000000000 ether
        );
        looksRareToken2 = new LooksRareToken(
            address(this),
            999970000 ether,
            1000000000 ether
        );
        //Non circulating supply = 1000000000 - 999970000 = 30000
        //Must match (rewardsPerBlockForStaking1 + rewardsPerBlockForOthers1) * periodLengthsInBlocks1 * numberPeriods

        tokenDistributorOriginal = new TokenDistributor(
            address(looksRareToken1),
            tokenSplitter,
            startBlock,
            rewardsPerBlockForStaking1,
            rewardsPerBlockForOthers1,
            periodLengthsInBlocks1,
            numberPeriods
        );

        tokenDistributorOptimized = new TokenDistributorOptimized(
            address(looksRareToken2),
            tokenSplitter,
            startBlock,
            numberPeriods,
            rewardsPerBlockForStaking2,
            rewardsPerBlockForOthers2,
            periodLengthsInBlocks2
        );

        looksRareToken1.approve(address(tokenDistributorOriginal), 1000000 ether);
        looksRareToken2.approve(address(tokenDistributorOptimized), 1000000 ether);
        looksRareToken1.transferOwnership(address(tokenDistributorOriginal));
        looksRareToken2.transferOwnership(address(tokenDistributorOptimized));
        vm.roll(startBlock);
    }

    //--------------------------------Unit tests for Original--------------------------------

    // function test_firstDeposit() public {
    //     tokenDistributorOriginal.deposit(1000 ether);
    //     (uint256 userInfoAmount, uint256 userInfoRewardDebt) = tokenDistributorOriginal.userInfo(address(this));
    //     uint256 totalAmountStaked = tokenDistributorOriginal.totalAmountStaked();
    //     assertEq(userInfoAmount, 1000 ether);
    //     assertEq(userInfoRewardDebt, 0);
    //     assertEq(totalAmountStaked, 1000 ether);
    // }

    // function test_twoDeposits() public {
    //     tokenDistributorOriginal.deposit(1000 ether);
    //     vm.roll(startBlock + 5);
    //     tokenDistributorOriginal.deposit(1000 ether);
    //     (uint256 userInfoAmount, uint256 userInfoRewardDebt) = tokenDistributorOriginal.userInfo(address(this));
    //     uint256 totalAmountStaked = tokenDistributorOriginal.totalAmountStaked();
    //     assertTrue(userInfoAmount > 2000 ether);
    //     assertTrue(userInfoRewardDebt > 0);
    //     assertTrue(totalAmountStaked > 2000 ether);
    //     assertEq(userInfoAmount, totalAmountStaked);
    // }

    // function test_harvestAndCompound() public {
    //     tokenDistributorOriginal.deposit(1000 ether);
    //     vm.roll(startBlock + 9);
    //     tokenDistributorOriginal.harvestAndCompound();
    //     (uint256 userInfoAmount, uint256 userInfoRewardDebt) = tokenDistributorOriginal.userInfo(address(this));
    //     uint256 totalAmountStaked = tokenDistributorOriginal.totalAmountStaked();
    //     assertTrue(userInfoAmount > 1000 ether);
    //     assertTrue(userInfoRewardDebt > 0);
    //     assertTrue(totalAmountStaked > 1000 ether);
    //     assertEq(userInfoAmount, totalAmountStaked);
    // }

    // function test_updatePool() public {
    //     tokenDistributorOriginal.deposit(1000 ether);
    //     uint256 endBlockInitial = tokenDistributorOriginal.endBlock();
    //     uint256 lastRewardBlockInitial = tokenDistributorOriginal.lastRewardBlock();
    //     uint256 accTokenPerShareInitial = tokenDistributorOriginal.accTokenPerShare();
    //     vm.roll(startBlock + 11);
    //     tokenDistributorOriginal.updatePool();
    //     uint256 endBlockAfter = tokenDistributorOriginal.endBlock();
    //     uint256 lastRewardBlockAfter = tokenDistributorOriginal.lastRewardBlock();
    //     uint256 accTokenPerShareAfter = tokenDistributorOriginal.accTokenPerShare();
    //     assertTrue(endBlockAfter > endBlockInitial);
    //     assertTrue(lastRewardBlockAfter > lastRewardBlockInitial);
    //     assertTrue(accTokenPerShareAfter > accTokenPerShareInitial);
    // }

    // function test_withdraw() public {
    //     tokenDistributorOriginal.deposit(1000 ether);
    //     uint256 initialBalance = looksRareToken1.balanceOf(address(this));
    //     vm.roll(startBlock + 10);
    //     tokenDistributorOriginal.withdraw(500 ether);
    //     uint256 finalBalance = looksRareToken1.balanceOf(address(this));
    //     assertEq(finalBalance, initialBalance + 500 ether);
    // }

    // function test_withdrawAll() public {
    //     tokenDistributorOriginal.deposit(1000 ether);
    //     uint256 initialBalance = looksRareToken1.balanceOf(address(this));
    //     vm.roll(startBlock + 10);
    //     tokenDistributorOriginal.withdrawAll();
    //     uint256 finalBalance = looksRareToken1.balanceOf(address(this));
    //     assertTrue(finalBalance > initialBalance + 1000 ether);
    // }

    // function test_calculatePendingRewards() public {
    //     tokenDistributorOriginal.deposit(1000 ether);
    //     vm.roll(startBlock + 10);
    //     uint256 pendingRewards = tokenDistributorOriginal.calculatePendingRewards(address(this));
    //     assertTrue(pendingRewards > 0);
    // }

    //--------------------------------Unit tests for Optimized--------------------------------

    function test_firstDeposit() public {
        tokenDistributorOptimized.deposit(1000 ether);
        (uint256 userInfoAmount, uint256 userInfoRewardDebt) = tokenDistributorOptimized.userInfo(address(this));
        uint256 totalAmountStaked = tokenDistributorOptimized.totalAmountStaked();
        assertEq(userInfoAmount, 1000 ether);
        assertEq(userInfoRewardDebt, 0);
        assertEq(totalAmountStaked, 1000 ether);
    }

    function test_twoDeposits() public {
        tokenDistributorOptimized.deposit(1000 ether);
        vm.roll(startBlock + 5);
        tokenDistributorOptimized.deposit(1000 ether);
        (uint256 userInfoAmount, uint256 userInfoRewardDebt) = tokenDistributorOptimized.userInfo(address(this));
        uint256 totalAmountStaked = tokenDistributorOptimized.totalAmountStaked();
        assertTrue(userInfoAmount > 2000 ether);
        assertTrue(userInfoRewardDebt > 0);
        assertTrue(totalAmountStaked > 2000 ether);
        assertEq(userInfoAmount, totalAmountStaked);
    }

    function test_harvestAndCompound() public {
        tokenDistributorOptimized.deposit(1000 ether);
        vm.roll(startBlock + 9);
        tokenDistributorOptimized.harvestAndCompound();
        (uint256 userInfoAmount, uint256 userInfoRewardDebt) = tokenDistributorOptimized.userInfo(address(this));
        uint256 totalAmountStaked = tokenDistributorOptimized.totalAmountStaked();
        assertTrue(userInfoAmount > 1000 ether);
        assertTrue(userInfoRewardDebt > 0);
        assertTrue(totalAmountStaked > 1000 ether);
        assertEq(userInfoAmount, totalAmountStaked);
    }

    function test_updatePool() public {
        tokenDistributorOptimized.deposit(1000 ether);
        uint256 endBlockInitial = tokenDistributorOptimized.endBlock();
        uint256 lastRewardBlockInitial = tokenDistributorOptimized.lastRewardBlock();
        uint256 accTokenPerShareInitial = tokenDistributorOptimized.accTokenPerShare();
        vm.roll(startBlock + 11);
        tokenDistributorOptimized.updatePool();
        uint256 endBlockAfter = tokenDistributorOptimized.endBlock();
        uint256 lastRewardBlockAfter = tokenDistributorOptimized.lastRewardBlock();
        uint256 accTokenPerShareAfter = tokenDistributorOptimized.accTokenPerShare();
        assertTrue(endBlockAfter > endBlockInitial);
        assertTrue(lastRewardBlockAfter > lastRewardBlockInitial);
        assertTrue(accTokenPerShareAfter > accTokenPerShareInitial);
    }

    function test_withdraw() public {
        tokenDistributorOptimized.deposit(1000 ether);
        uint256 initialBalance = looksRareToken2.balanceOf(address(this));
        vm.roll(startBlock + 10);
        tokenDistributorOptimized.withdraw(500 ether);
        uint256 finalBalance = looksRareToken2.balanceOf(address(this));
        assertEq(finalBalance, initialBalance + 500 ether);
    }

    function test_withdrawAll() public {
        tokenDistributorOptimized.deposit(1000 ether);
        uint256 initialBalance = looksRareToken2.balanceOf(address(this));
        vm.roll(startBlock + 10);
        tokenDistributorOptimized.withdrawAll();
        uint256 finalBalance = looksRareToken2.balanceOf(address(this));
        assertTrue(finalBalance > initialBalance + 1000 ether);
    }

    function test_calculatePendingRewards() public {
        tokenDistributorOptimized.deposit(1000 ether);
        vm.roll(startBlock + 10);
        uint256 pendingRewards = tokenDistributorOptimized.calculatePendingRewards(address(this));
        assertTrue(pendingRewards > 0);
    }
}