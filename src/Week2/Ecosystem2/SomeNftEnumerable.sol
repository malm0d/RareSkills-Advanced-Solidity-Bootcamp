//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721Enumerable} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract SomeNFTEnumerable is ERC721Enumerable, Ownable2Step, Pausable, ReentrancyGuard {
    uint256 public constant MAX_SUPPLY = 100;

    event Mint(address indexed to, uint256 indexed tokenId);

    /**
     * @dev declare payable to save some gas on deployment
     */
    constructor() payable ERC721("SomeNFTEnum", "SOMEE") Ownable(msg.sender) {}

    function mint() external nonReentrant whenNotPaused {
        require(totalSupply() < MAX_SUPPLY, "All tokens have been minted");
        uint256 tokenIdToMint = totalSupply() + 1;
        _safeMint(msg.sender, tokenIdToMint);
        emit Mint(msg.sender, tokenIdToMint);
    }

    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    function unpause() external whenPaused onlyOwner {
        _unpause();
    }
}
