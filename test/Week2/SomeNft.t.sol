// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {SomeNFT} from "../../src/Week2/Ecosystem1/SomeNFT.sol";

contract SomeNFTTest is Test {
    SomeNFT someNFT;
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

    function testMint() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 1 ether);
        someNFT.mint{value: 1 ether}();
        assertEq(someNFT.balanceOf(normalUser), 1);
    }

    function testMintOutOfSupply() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 5000000 ether);
        for (uint256 i = 0; i < 1000; i++) {
            someNFT.mint{value: 1 ether}();
        }
        vm.expectRevert("All tokens have been minted");
        someNFT.mint{value: 1 ether}();
        vm.stopPrank();
    }

    function testWithdraw() public {
        vm.startPrank(normalUser);
        vm.deal(normalUser, 5000000 ether);
        someNFT.mint{value: 1 ether}();

        vm.startPrank(owner);
        uint256 balanceBefore = address(owner).balance;
        someNFT.withdrawFunds();
        uint256 balanceAfter = address(owner).balance;
        assertGt(balanceAfter, balanceBefore);
    }

    function testRoyalties() public {
        uint256 balanceBefore = address(royaltyReceiver).balance;

        vm.startPrank(normalUser);
        vm.deal(normalUser, 50 ether);
        for (uint256 i = 0; i < 10; i++) {
            someNFT.mint{value: 1 ether}();
        }

        uint256 balanceAfter = address(royaltyReceiver).balance;
        assertGt(balanceAfter, balanceBefore);
    }

    receive() external payable {}
}