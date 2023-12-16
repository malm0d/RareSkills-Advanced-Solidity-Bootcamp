// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {SomeNFT} from "../../src/Week2/Ecosystem1/SomeNFT.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

//forge test --match-contract SomeNFTTest -vvvv
contract SomeNFTTest is Test {
    SomeNFT someNFT;
    //SomeNFTEnumerable enumerableContract;
    address owner;
    address royaltyReceiver;
    address userWithDiscount1;
    address userWithDiscount2;
    address normalUser;
    bytes32 merkleRoot = 0xa297e088bf87eea455a2cbb55853136013d1f0c222822827516f97639984ec19;
    uint256 MAX_SUPPLY;

    function setUp() public {
        owner = address(this);
        royaltyReceiver = address(0x777);
        userWithDiscount1 = 0x0000000000000000000000000000000000000001;
        userWithDiscount2 = 0x0000000000000000000000000000000000000002;
        normalUser = address(0x100);
        someNFT = new SomeNFT(merkleRoot, royaltyReceiver);
        MAX_SUPPLY = someNFT.MAX_SUPPLY();
    }

    function testRoyaltyZeroAddress() public {
        vm.expectRevert("Cannot be the zero address");
        new SomeNFT(merkleRoot, address(0));
    }

    function testNameAndSymbol() public {
        SomeNFT _someNFT = new SomeNFT(merkleRoot, royaltyReceiver);
        assertEq(_someNFT.name(), "SomeNFT");
        assertEq(_someNFT.symbol(), "SOME");
        assertEq(_someNFT.owner(), owner);
        assertEq(_someNFT.merkleRoot(), merkleRoot);
    }

    function testMintWithDiscount() public {
        vm.startPrank(userWithDiscount1);
        bytes32[] memory proofUser1 = new bytes32[](3);
        proofUser1[0] = 0x50bca9edd621e0f97582fa25f616d475cabe2fd783c8117900e5fed83ec22a7c;
        proofUser1[1] = 0x63340ab877f112a2b7ccdbf0eb0f6d9f757ab36ecf6f6e660df145bcdfb67a19;
        proofUser1[2] = 0x4faf7b0021ef54912575fc1dca53650228f33fe7ae7f3bf151ce2b9faa8e6ffd;
        vm.deal(userWithDiscount1, 1 ether);
        someNFT.mintWithDiscount{value: 0.5 ether}(proofUser1, 0);
        assertEq(someNFT.balanceOf(userWithDiscount1), 1);
        vm.stopPrank();

        vm.startPrank(userWithDiscount2);
        bytes32[] memory proofUser2 = new bytes32[](3);
        proofUser2[0] = 0x5fa3dab1e0e1070445c119c6fd10edd16d6aa2f25a5899217f919c041d474318;
        proofUser2[1] = 0x895c5cff012220658437b539cdf2ce853576fc0a881d814e6c7da6b20e9b8d8d;
        proofUser2[2] = 0x4faf7b0021ef54912575fc1dca53650228f33fe7ae7f3bf151ce2b9faa8e6ffd;
        vm.deal(userWithDiscount2, 1 ether);
        someNFT.mintWithDiscount{value: 0.5 ether}(proofUser2, 1);
        assertEq(someNFT.balanceOf(userWithDiscount2), 1);
        vm.stopPrank();
    }

    function testMintWithDiscountWrongPrice() public {
        vm.startPrank(userWithDiscount1);
        bytes32[] memory proofUser1 = new bytes32[](3);
        proofUser1[0] = 0x50bca9edd621e0f97582fa25f616d475cabe2fd783c8117900e5fed83ec22a7c;
        proofUser1[1] = 0x63340ab877f112a2b7ccdbf0eb0f6d9f757ab36ecf6f6e660df145bcdfb67a19;
        proofUser1[2] = 0x4faf7b0021ef54912575fc1dca53650228f33fe7ae7f3bf151ce2b9faa8e6ffd;
        vm.deal(userWithDiscount1, 1 ether);
        vm.expectRevert("Incorrect payment amount");
        someNFT.mintWithDiscount{value: 0.9 ether}(proofUser1, 0);
        vm.stopPrank();
    }

    function testMintWithDiscountTwiceFailure() public {
        vm.startPrank(userWithDiscount1);
        bytes32[] memory proofUser1 = new bytes32[](3);
        proofUser1[0] = 0x50bca9edd621e0f97582fa25f616d475cabe2fd783c8117900e5fed83ec22a7c;
        proofUser1[1] = 0x63340ab877f112a2b7ccdbf0eb0f6d9f757ab36ecf6f6e660df145bcdfb67a19;
        proofUser1[2] = 0x4faf7b0021ef54912575fc1dca53650228f33fe7ae7f3bf151ce2b9faa8e6ffd;
        vm.deal(userWithDiscount1, 2 ether);
        someNFT.mintWithDiscount{value: 0.5 ether}(proofUser1, 0);
        assertEq(someNFT.balanceOf(userWithDiscount1), 1);

        vm.expectRevert("Already minted with discount");
        someNFT.mintWithDiscount{value: 0.5 ether}(proofUser1, 0);

        vm.stopPrank();
    }

    function testMintWithDiscountInvalidProof() public {
        vm.startPrank(userWithDiscount1);
        bytes32[] memory proofUser1 = new bytes32[](3);
        proofUser1[0] = 0x50bca9edd621e0f97582fa25f616d475cabe2fd783c8117900e5fed83ec22a7c;
        proofUser1[1] = 0x63340ab877f112a2b7ccdbf0eb0f6d9f757ab36ecf6f6e660df145bcdfb67a19;
        proofUser1[2] = 0x4faf7b0021ef54912575fc1dca53650228f33fe7ae7f3bf151ce2b9faa8e6ffd;
        vm.deal(userWithDiscount1, 1 ether);
        vm.expectRevert("Invalid merkle proof");
        someNFT.mintWithDiscount{value: 0.5 ether}(proofUser1, 5);
        vm.stopPrank();
    }

    function testMintWithDiscountRoyaltyAmount() public {
        uint256 royaltiesReceiverBalanceBefore = address(royaltyReceiver).balance;

        vm.startPrank(userWithDiscount1);
        bytes32[] memory proofUser1 = new bytes32[](3);
        proofUser1[0] = 0x50bca9edd621e0f97582fa25f616d475cabe2fd783c8117900e5fed83ec22a7c;
        proofUser1[1] = 0x63340ab877f112a2b7ccdbf0eb0f6d9f757ab36ecf6f6e660df145bcdfb67a19;
        proofUser1[2] = 0x4faf7b0021ef54912575fc1dca53650228f33fe7ae7f3bf151ce2b9faa8e6ffd;
        vm.deal(userWithDiscount1, 1 ether);
        someNFT.mintWithDiscount{value: 0.5 ether}(proofUser1, 0);
        vm.stopPrank();

        uint256 royaltiesreceiverBalanceAfter = address(royaltyReceiver).balance;

        assertGt(royaltiesreceiverBalanceAfter, royaltiesReceiverBalanceBefore);
        assertEq(royaltiesreceiverBalanceAfter, (0.5 ether * 250) / 10000);
    }

    function testMintWithDiscountFailsOnRoyaltyPayment() public {
        RejectingReceiver rejectingReceiver = new RejectingReceiver();
        SomeNFT someNFT_testContract = new SomeNFT(merkleRoot, address(rejectingReceiver));

        vm.startPrank(userWithDiscount1);
        bytes32[] memory proofUser1 = new bytes32[](3);
        proofUser1[0] = 0x50bca9edd621e0f97582fa25f616d475cabe2fd783c8117900e5fed83ec22a7c;
        proofUser1[1] = 0x63340ab877f112a2b7ccdbf0eb0f6d9f757ab36ecf6f6e660df145bcdfb67a19;
        proofUser1[2] = 0x4faf7b0021ef54912575fc1dca53650228f33fe7ae7f3bf151ce2b9faa8e6ffd;
        vm.deal(userWithDiscount1, 1 ether);
        vm.expectRevert("Royalties payment failed");
        someNFT_testContract.mintWithDiscount{value: 0.5 ether}(proofUser1, 0);
    }

    function testMintWithDiscountOutOfSupply() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 5000000 ether);
        for (uint256 i = 0; i < MAX_SUPPLY - 1; i++) {
            someNFT.mint{value: 1 ether}();
        }
        vm.stopPrank();

        vm.startPrank(userWithDiscount1);
        bytes32[] memory proofUser1 = new bytes32[](3);
        proofUser1[0] = 0x50bca9edd621e0f97582fa25f616d475cabe2fd783c8117900e5fed83ec22a7c;
        proofUser1[1] = 0x63340ab877f112a2b7ccdbf0eb0f6d9f757ab36ecf6f6e660df145bcdfb67a19;
        proofUser1[2] = 0x4faf7b0021ef54912575fc1dca53650228f33fe7ae7f3bf151ce2b9faa8e6ffd;
        vm.deal(userWithDiscount1, 1 ether);
        someNFT.mintWithDiscount{value: 0.5 ether}(proofUser1, 0);
        assertEq(someNFT.balanceOf(userWithDiscount1), 1);

        vm.startPrank(userWithDiscount2);
        bytes32[] memory proofUser2 = new bytes32[](3);
        proofUser2[0] = 0x5fa3dab1e0e1070445c119c6fd10edd16d6aa2f25a5899217f919c041d474318;
        proofUser2[1] = 0x895c5cff012220658437b539cdf2ce853576fc0a881d814e6c7da6b20e9b8d8d;
        proofUser2[2] = 0x4faf7b0021ef54912575fc1dca53650228f33fe7ae7f3bf151ce2b9faa8e6ffd;
        vm.deal(userWithDiscount2, 1 ether);
        vm.expectRevert("All tokens have been minted");
        someNFT.mintWithDiscount{value: 0.5 ether}(proofUser2, 1);
        assertEq(someNFT.balanceOf(userWithDiscount2), 0);
    }

    function testMint() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 1 ether);
        someNFT.mint{value: 1 ether}();
        assertEq(someNFT.balanceOf(normalUser), 1);
    }

    function testMintWrongPrice() external {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 1 ether);
        vm.expectRevert("Incorrect payment amount");
        someNFT.mint{value: 0.9 ether}();
    }

    function testMintOutOfSupply() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 5000000 ether);
        for (uint256 i = 0; i < MAX_SUPPLY; i++) {
            someNFT.mint{value: 1 ether}();
        }
        vm.expectRevert("All tokens have been minted");
        someNFT.mint{value: 1 ether}();
        vm.stopPrank();
    }

    function testMintFailsOnRoyaltyPayment() public {
        RejectingReceiver rejectingReceiver = new RejectingReceiver();
        SomeNFT someNFT_testContract = new SomeNFT(merkleRoot, address(rejectingReceiver));

        vm.startPrank(normalUser);
        vm.deal(normalUser, 1 ether);
        vm.expectRevert("Royalties payment failed");
        someNFT_testContract.mint{value: 1 ether}();
    }

    function tesMinttRoyaltiesAmount() public {
        uint256 balanceBefore = address(royaltyReceiver).balance;

        vm.startPrank(normalUser);
        vm.deal(normalUser, 50 ether);
        for (uint256 i = 0; i < 10; i++) {
            someNFT.mint{value: 1 ether}();
        }

        uint256 balanceAfter = address(royaltyReceiver).balance;
        assertGt(balanceAfter, balanceBefore);
    }

    function testWithdrawFunds() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 5000000 ether);
        someNFT.mint{value: 1 ether}();
        vm.stopPrank();

        vm.startPrank(owner);
        uint256 balanceBefore = address(owner).balance;
        someNFT.withdrawFunds();
        uint256 balanceAfter = address(owner).balance;
        assertGt(balanceAfter, balanceBefore);
    }

    function testWithdrawFundsFail() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 5000000 ether);
        someNFT.mint{value: 1 ether}();
        vm.expectRevert();
        someNFT.withdrawFunds();
    }

    function testWithdrawLowLevelCallFail() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 5000000 ether);
        someNFT.mint{value: 1 ether}();
        vm.stopPrank();

        RejectingReceiver rejectingReceiver = new RejectingReceiver();
        vm.startPrank(address(this));
        someNFT.transferOwnership(address(rejectingReceiver));
        vm.stopPrank();

        vm.startPrank(address(rejectingReceiver));
        someNFT.acceptOwnership();
        vm.expectRevert("Withdrawal failed");
        someNFT.withdrawFunds();
    }

    function testSupportsInterface() public {
        //interface Id for ERC721 is 0x80ac58cd
        //interface Id for ERC2981 is 0x2a55205a
        assertEq(someNFT.supportsInterface(0x80ac58cd), true);
        assertEq(someNFT.supportsInterface(0x2a55205a), true);
        assertEq(someNFT.supportsInterface(0x780e9d63), false);
    }

    function testReentrancyGuardMint() public {
        MaliciousContract maliciousContract = new MaliciousContract(address(someNFT));
        vm.deal(address(maliciousContract), 10 ether);
        vm.expectRevert(bytes4(keccak256(bytes("ReentrancyGuardReentrantCall()"))));
        maliciousContract.mintNFTAttack();
    }

    receive() external payable {}
}

contract RejectingReceiver {
    receive() external payable {
        revert("RejectingReceiver: Revert");
    }
}

contract MaliciousContract is IERC721Receiver {
    SomeNFT public someNFT;

    constructor(address _nftContract) {
        someNFT = SomeNFT(_nftContract);
    }

    function mintNFTAttack() external {
        someNFT.mint{value: 1 ether}();
    }

    function onERC721Received(address, address, uint256, bytes calldata) external returns (bytes4) {
        someNFT.mint{value: 1 ether}();
        return IERC721Receiver.onERC721Received.selector;
    }
}
