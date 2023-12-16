// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {StakingNFT} from "../../src/Week2/Ecosystem1/Staking.sol";
import {RewardToken} from "../../src/Week2/Ecosystem1/RewardToken.sol";
import {SomeNFT} from "../../src/Week2/Ecosystem1/SomeNFT.sol";
import {SomeNFTEnumerable} from "../../src/Week2/Ecosystem2/SomeNftEnumerable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

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
    address otherUser;
    bytes32 merkleRoot = 0xa297e088bf87eea455a2cbb55853136013d1f0c222822827516f97639984ec19;

    function setUp() public {
        owner = address(this);
        royaltyReceiver = address(0x777);
        userWithDiscount1 = 0x0000000000000000000000000000000000000001;
        userWithDiscount2 = 0x0000000000000000000000000000000000000002;
        normalUser = address(0x100);
        otherUser = address(0x101);
        someNFT = new SomeNFT(merkleRoot, royaltyReceiver);

        rewardToken = new RewardToken();
        stakingContract = new StakingNFT(address(someNFT), address(rewardToken));
        rewardToken.updateStakingContract(address(stakingContract));

        falseNFTContract = new SomeNFTEnumerable();
    }

    function testNFTNameAndSymbol() public {
        string memory name = someNFT.name();
        string memory symbol = someNFT.symbol();
        address ownr = someNFT.owner();
        bytes32 mrklRt = someNFT.merkleRoot();

        assertEq(name, "SomeNFT");
        assertEq(symbol, "SOME");
        assertEq(ownr, owner);
        assertEq(mrklRt, merkleRoot);
    }

    //******************Testing Reward Token*******************/

    function testTokenInit() public {
        string memory name = rewardToken.name();
        string memory symbol = rewardToken.symbol();
        address ownr = rewardToken.owner();
        uint256 amt = stakingContract.MINT_AMOUNT();

        assertEq(name, "RewardToken");
        assertEq(symbol, "RT");
        assertEq(ownr, owner);
        assertEq(amt, 10 * (10 ** 18));
    }

    function testRewardToken() public {
        vm.startPrank(normalUser);
        vm.expectRevert();
        rewardToken.updateStakingContract(address(0x07));
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectRevert("Cannot be the zero address");
        rewardToken.updateStakingContract(address(0x00));

        vm.startPrank(normalUser);
        vm.expectRevert("Only staking contract can mint rewards");
        rewardToken.mintRewards(owner, 1_000e18);

        assertEq(rewardToken.name(), "RewardToken");
        assertEq(rewardToken.symbol(), "RT");
        assertEq(rewardToken.owner(), owner);
    }

    //******************Test Staking to Staking Contract*******************/

    function testStakeNFTFailInvalidTokenId() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 1 ether);
        someNFT.mint{value: 1 ether}();
        vm.expectRevert();
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 1);
    }

    function testTransferNFTFailUntrustedContract() public {
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

    //******************Test Withdraw from Staking Contract*******************/

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

    function testWithdrawNFTFailOnPaused() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 1 ether);
        someNFT.mint{value: 1 ether}();
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 0);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.deal(owner, 1 ether);
        stakingContract.pause();
        vm.stopPrank();

        vm.startPrank(normalUser);
        vm.expectRevert();
        stakingContract.withdrawNFT(0);
    }

    function testWithdrawNFTUnpaused() public {
        vm.warp(1 days);

        vm.startPrank(normalUser);
        vm.deal(normalUser, 1 ether);
        someNFT.mint{value: 1 ether}();
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 0);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.deal(owner, 1 ether);
        stakingContract.pause();
        vm.stopPrank();

        vm.startPrank(normalUser);
        vm.expectRevert();
        stakingContract.withdrawNFT(0);

        vm.startPrank(owner);
        stakingContract.unpause();
        vm.stopPrank();

        vm.startPrank(normalUser);
        stakingContract.withdrawNFT(0);
        assertEq(someNFT.ownerOf(0), normalUser);
        assertEq(someNFT.balanceOf(address(stakingContract)), 0);
        assertEq(someNFT.balanceOf(normalUser), 1);
    }

    function testWithdrawNFTBefore24Hours() public {
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
        assertEq(initialClaimTime, 1);
        assertEq(finalClaimTime, 0);
    }

    function testWithdrawAfter24Hours() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 1 ether);
        someNFT.mint{value: 1 ether}();
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 0);
        uint256 initialBalance = rewardToken.balanceOf(normalUser);

        vm.warp(1.1 days);
        stakingContract.withdrawNFT(0);
        uint256 finalBalance = rewardToken.balanceOf(normalUser);
        assertEq(someNFT.ownerOf(0), normalUser);
        assertEq(someNFT.balanceOf(address(stakingContract)), 0);
        assertEq(someNFT.balanceOf(normalUser), 1);
        assertEq(finalBalance - initialBalance, 10 * (10 ** 18));
    }

    function testWithdrawOn24Hours() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 1 ether);
        someNFT.mint{value: 1 ether}();
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 0);
        uint256 initialBalance = rewardToken.balanceOf(normalUser);

        vm.warp(1 days);
        stakingContract.withdrawNFT(0);
        uint256 finalBalance = rewardToken.balanceOf(normalUser);
        assertEq(someNFT.ownerOf(0), normalUser);
        assertEq(someNFT.balanceOf(address(stakingContract)), 0);
        assertEq(someNFT.balanceOf(normalUser), 1);
        assertEq(finalBalance, initialBalance);
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

    function testCompareWithdrawNFTMintAmounts() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 1 ether);
        someNFT.mint{value: 1 ether}();
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 0);
        stakingContract.withdrawNFT(0);
        uint256 balanceScenarioOne = rewardToken.balanceOf(normalUser);
        assertEq(balanceScenarioOne, 0);

        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 0);
        vm.warp(1 days);
        stakingContract.withdrawNFT(0);
        uint256 balanceScenarioTwo = rewardToken.balanceOf(normalUser);
        assertEq(balanceScenarioTwo, 0);

        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 0);
        vm.warp(2 days);
        stakingContract.withdrawNFT(0);
        uint256 balanceScenarioThree = rewardToken.balanceOf(normalUser);
        assertEq(balanceScenarioThree, 10 * (10 ** 18));
    }

    function testWithdrawReentrancy() public {
        MaliciousContract2 maliciousContract2 = new MaliciousContract2(address(stakingContract), address(someNFT));
        vm.startPrank(owner);
        vm.deal(owner, 5 ether);
        someNFT.mint{value: 1 ether}();
        someNFT.transferFrom(owner, address(maliciousContract2), 0);

        vm.startPrank(address(maliciousContract2));
        vm.deal(address(maliciousContract2), 5 ether);
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(address(maliciousContract2), address(stakingContract), 0);
        vm.warp(2 days);
        vm.expectRevert(bytes4(keccak256(bytes("ReentrancyGuardReentrantCall()"))));
        maliciousContract2.withdrawalAttack();
    }

    //******************Test Claim Rewards from Staking Contract*******************/

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

    function testClaimRewards1() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 5 ether);
        someNFT.mint{value: 1 ether}();
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 0);
        uint256 initialBalance = rewardToken.balanceOf(normalUser);
        assertEq(initialBalance, 0);

        vm.expectRevert("Can only claim after every 24 hours");
        stakingContract.claimRewards(0);

        vm.warp(1 days);
        vm.expectRevert("Can only claim after every 24 hours");
        stakingContract.claimRewards(0);

        vm.warp(1.1 days);
        stakingContract.claimRewards(0);
        uint256 finalBalance = rewardToken.balanceOf(normalUser);
        assertEq(finalBalance, 10 * (10 ** 18));
    }

    function testClaimRewards2() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 5 ether);
        someNFT.mint{value: 1 ether}();
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 0);
        uint256 initialBalance = rewardToken.balanceOf(normalUser);
        assertEq(initialBalance, 0);

        vm.warp(1.5 days); //from 0
        stakingContract.claimRewards(0);
        uint256 updatedBalance = rewardToken.balanceOf(normalUser);
        assertEq(updatedBalance, 10 * (10 ** 18));

        vm.warp(2.4 days); //from 0
        vm.expectRevert("Can only claim after every 24 hours");
        stakingContract.claimRewards(0);

        vm.warp(2.5 days);
        stakingContract.claimRewards(0);
        uint256 finalBalance = rewardToken.balanceOf(normalUser);
        assertEq(finalBalance, 20 * (10 ** 18));
    }

    function testClaimRewardsFailOnPaused() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 5 ether);
        someNFT.mint{value: 1 ether}();
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 0);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.deal(owner, 1 ether);
        stakingContract.pause();
        vm.stopPrank();

        vm.startPrank(normalUser);
        vm.warp(1.5 days);
        vm.expectRevert();
        stakingContract.claimRewards(0);
    }

    function testClaimRewardsUnpaused() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 5 ether);
        someNFT.mint{value: 1 ether}();
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(normalUser, address(stakingContract), 0);
        uint256 intialBalance = rewardToken.balanceOf(normalUser);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.deal(owner, 1 ether);
        stakingContract.pause();
        vm.stopPrank();

        vm.startPrank(normalUser);
        vm.warp(1.5 days);
        vm.expectRevert();
        stakingContract.claimRewards(0);

        vm.startPrank(owner);
        stakingContract.unpause();
        vm.stopPrank();

        vm.startPrank(normalUser);
        stakingContract.claimRewards(0);
        uint256 finalBalance = rewardToken.balanceOf(normalUser);
        assertEq(finalBalance - intialBalance, 10 * (10 ** 18));
    }

    function testClaimReentrancy() public {
        MaliciousContract maliciousContract = new MaliciousContract(address(stakingContract));
        vm.startPrank(address(maliciousContract));
        vm.deal(address(maliciousContract), 5 ether);
        someNFT.mint{value: 1 ether}();
        someNFT.approve(address(stakingContract), 0);
        someNFT.safeTransferFrom(address(maliciousContract), address(stakingContract), 0);
        vm.warp(block.timestamp + 1 days + 1);
        vm.expectRevert("Can only claim after every 24 hours");
        maliciousContract.attack(0);
        //This test does not really test reentrancy.
        //One way to test reentrancy is to use a malicious reward token in the staking contract,
        //but this is not realistic in a sense because the reward token should always be a
        //trusted contract.
    }

    function testPause() public {
        assertEq(stakingContract.paused(), false);

        vm.startPrank(owner);
        stakingContract.pause();
        assertEq(stakingContract.paused(), true);

        vm.expectRevert(bytes4(keccak256(bytes("EnforcedPause()"))));
        stakingContract.pause();

        stakingContract.unpause();
        assertEq(stakingContract.paused(), false);

        vm.expectRevert(bytes4(keccak256(bytes("ExpectedPause()"))));
        stakingContract.unpause();

        vm.stopPrank();

        vm.startPrank(normalUser);
        vm.expectRevert();
        stakingContract.pause();

        vm.stopPrank();

        vm.startPrank(owner);
        stakingContract.pause();
        assertEq(stakingContract.paused(), true);

        vm.startPrank(normalUser);
        vm.expectRevert();
        stakingContract.unpause();
    }

    function testStakingContractOwner() public {
        assertEq(stakingContract.owner(), owner);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}

contract MaliciousContract2 is IERC721Receiver {
    StakingNFT public stakingNFTContract;
    SomeNFT public someNFTContract;

    constructor(address _stakingContract, address _someNFTContract) {
        stakingNFTContract = StakingNFT(_stakingContract);
        someNFTContract = SomeNFT(_someNFTContract);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        stakingNFTContract.withdrawNFT(0);
        return IERC721Receiver.onERC721Received.selector;
    }

    function withdrawalAttack() public {
        stakingNFTContract.withdrawNFT(0);
    }
}

contract MaliciousContract is IERC721Receiver {
    StakingNFT public stakingNFTContract;

    constructor(address _stakingContract) {
        stakingNFTContract = StakingNFT(_stakingContract);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function attack(uint256 _tokenId) public {
        // First call to claimRewards
        stakingNFTContract.claimRewards(_tokenId);

        //Second call to claimRewards
        stakingNFTContract.claimRewards(_tokenId);
    }
}
