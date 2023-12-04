// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {SomeNFTEnumerable} from "../../src/Week2/Ecosystem2/SomeNFTEnumerable.sol";
import {IsPrimeOnSteroids} from "../../src/Week2/Ecosystem2/IsPrimeOnSteroids.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract Ecosystem2Test is Test {
    SomeNFTEnumerable someNFTEnumerable;
    IsPrimeOnSteroids isPrimeOnSteroids;
    address owner;

    function setUp() public {
        owner = address(this);
        someNFTEnumerable = new SomeNFTEnumerable();
        isPrimeOnSteroids = new IsPrimeOnSteroids(address(someNFTEnumerable));
    }

    function testCountPrimes() public {
        vm.startPrank(owner);
        vm.deal(owner, 5000000 ether);
        for (uint256 i = 0; i < 10; i++) {
            someNFTEnumerable.mint();
        }
        vm.stopPrank();
        uint256 res = isPrimeOnSteroids.countPrimes(owner);
        assertEq(res, 4);

        bool res2 = isPrimeOnSteroids._isPrimeNumber(17);
        assertEq(res2, true);
    }

    function onERC721Received(address, address, uint256, bytes calldata) external pure returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }
}
