//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {RewardToken} from "./RewardToken.sol";
import {SomeNFT} from "./SomeNFT.sol";

contract StakingNFT is IERC721Receiver, Ownable2Step, ReentrancyGuard {
    SomeNFT public someNFTContract;
    RewardToken public rewardTokenContract;

    constructor(address _someNFT, address _rewardToken) Ownable(msg.sender) {
        someNFTContract = SomeNFT(_someNFT);
        rewardTokenContract = RewardToken(_rewardToken);
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    )
        external
        returns (bytes4)
    {
        /**
         * @dev the msg.sender will be the ERC721 contract, NOT the owner of the token,
         * as the ERC721 contract itself will call this function when `_checkOnERC721Received` is called
         * in the execution of the `safeTransferFrom` function (fyi: also during _safeMint).
         *
         * Check that the msg.sender is the ERC721 contract, and check that the tokenId is valid.
         * Accept the token if its valid, otherwise we must revert.
         */
        require(msg.sender == address(someNFTContract), "Caller is not the ERC721 contract");
        require(!(tokenId > someNFTContract.currentSupply()), "Token ID is invalid");
        //do some....

        return IERC721Receiver.onERC721Received.selector;
    }
}
