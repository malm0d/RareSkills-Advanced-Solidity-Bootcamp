// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {StakingNFT} from "../../src/Week2/Ecosystem1/Staking.sol";
import {RewardToken} from "../../src/Week2/Ecosystem1/RewardToken.sol";
import {SomeNFT} from "../../src/Week2/Ecosystem1/SomeNFT.sol";
import {SomeNFTEnumerable} from "../../src/Week2/Ecosystem2/SomeNftEnumerable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract StakingTest is Test {
    StakingNFT stakingContract;
    SomeNFT someNFT;
    SomeNFTEnumerable falseNFTContract;
    RewardToken rewardToken;
    address owner;
    address royaltyReceiver;
    address userWithDiscount1;
    address userWithDiscount2;
    address normalUser;
    bytes32 merkleRoot = 0xa297e088bf87eea455a2cbb55853136013d1f0c222822827516f97639984ec19;

    function setUp() public {
        owner = address(this);
        royaltyReceiver = address(0x777);
        userWithDiscount1 = 0x0000000000000000000000000000000000000001;
        userWithDiscount2 = 0x0000000000000000000000000000000000000002;
        normalUser = address(0x100);
        someNFT = new SomeNFT(merkleRoot, royaltyReceiver);

        rewardToken = new RewardToken();
        stakingContract = new StakingNFT(address(someNFT), address(rewardToken));
        rewardToken.updateStakingContract(address(stakingContract));

        falseNFTContract = new SomeNFTEnumerable();
    }

    function testStakeNFTFailInvalidTokenId() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 1 ether);
        someNFT.mint{value: 1 ether}();
        vm.expectRevert();
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 1);
    }

    function testTransferNFTFail() public {
        vm.startPrank(owner);
        vm.deal(owner, 2 ether);
        someNFT.mint{value: 1 ether}(); // tokenId = 0
        someNFT.mint{value: 1 ether}(); // tokenId = 1
        falseNFTContract.mint(); //tokenId = 1
        vm.expectRevert("Caller is not the ERC721 contract");
        falseNFTContract.safeTransferFrom(owner, address(stakingContract), 1);
    }

    function testStakeNFT() public {
        vm.startPrank(owner);
        vm.deal(owner, 2 ether);
        someNFT.mint{value: 1 ether}(); // tokenId = 0
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(owner, address(stakingContract), 0);
        address originalOwner = stakingContract.getOriginalOwner(0);
        assertEq(someNFT.ownerOf(0), address(stakingContract));
        assertEq(someNFT.balanceOf(address(stakingContract)), 1);
        assertEq(someNFT.balanceOf(owner), 0);
        assertEq(owner, originalOwner);
    }

    function testWithdrawNFTFail() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 1 ether);
        someNFT.mint{value: 1 ether}();
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 0);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectRevert("Only the original owner can withdraw");
        stakingContract.withdrawNFT(0);
    }

    function testWithdrawNFT() public {
        vm.warp(1 days);

        vm.startPrank(normalUser);
        vm.deal(normalUser, 1 ether);
        someNFT.mint{value: 1 ether}();
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 0);
        uint256 initialClaimTime = stakingContract.getClaimTime(0);

        stakingContract.withdrawNFT(0);
        uint256 finalClaimTime = stakingContract.getClaimTime(0);
        assertEq(someNFT.ownerOf(0), normalUser);
        assertEq(someNFT.balanceOf(address(stakingContract)), 0);
        assertEq(someNFT.balanceOf(normalUser), 1);
        assertEq(initialClaimTime, 1 days);
        assertNotEq(initialClaimTime, finalClaimTime);
        assertEq(finalClaimTime, 0);
    }

    function testClaimRewardsFail() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 5 ether);
        someNFT.mint{value: 1 ether}(); // tokenId = 0
        someNFT.mint{value: 1 ether}(); // tokenId = 1
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 0);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectRevert("This token ID is not staked");
        stakingContract.claimRewards(1);
        vm.expectRevert("Only the original owner can claim rewards for this token ID");
        stakingContract.claimRewards(0);
        vm.stopPrank();

        vm.startPrank(normalUser);
        vm.expectRevert("Can only claim after every 24 hours");
        stakingContract.claimRewards(0);
    }

    function testClaimRewardsAfter24Hours() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 5 ether);
        someNFT.mint{value: 1 ether}();
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 0);
        uint256 intialBalance = rewardToken.balanceOf(normalUser);
        vm.warp(1.5 days);
        stakingContract.claimRewards(0);
        uint256 finalBalance = rewardToken.balanceOf(normalUser);
        assertEq(finalBalance - intialBalance, 10 * (10 ** 18));
    }

    function testWithdrawNFTWithoutClaimingRewardsAfter24Hours() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 1 ether);
        someNFT.mint{value: 1 ether}();
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 0);
        uint256 intialBalance = rewardToken.balanceOf(normalUser);
        vm.warp(1.1 days);
        stakingContract.withdrawNFT(0);
        uint256 finalBalance = rewardToken.balanceOf(normalUser);
        assertEq(finalBalance - intialBalance, 10 * (10 ** 18));
    }

    function testWithdrawAfterClaimingRewards() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 2 ether);
        someNFT.mint{value: 1 ether}();
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 0);
        uint256 intialBalance = rewardToken.balanceOf(normalUser);
        vm.warp(1.1 days);
        stakingContract.claimRewards(0);
        vm.warp(7 days);
        stakingContract.claimRewards(0);
        stakingContract.withdrawNFT(0);
        uint256 finalBalance = rewardToken.balanceOf(normalUser);
        assertEq(finalBalance - intialBalance, 2 * (10 * (10 ** 18)));
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
