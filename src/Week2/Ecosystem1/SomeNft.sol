//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

//A quick point: we could use ERC721Royalty which combines both 721 and 2981, but for practice, we will use the latter two.

contract SomeNFT is ERC721, ERC2981, Ownable2Step, Pausable, ReentrancyGuard {
    using BitMaps for BitMaps.BitMap;

    bytes32 public immutable merkleRoot;
    uint256 public constant MAX_SUPPLY = 1000;
    uint256 public currentSupply; //also acts as the tokenId counter, so first tokenId is 0, last is 999
    uint256 public constant MINT_PRICE = 1 ether;
    uint96 public constant ROYALTY_FRACTION = 250; // 2.5% royalties
    uint8 public constant DISCOUNT_FACTOR = 2; // For 50% discount

    BitMaps.BitMap private addressDiscountedMints;

    event Mint(address indexed to, uint256 indexed tokenId);
    event WithdrawFunds(address indexed to);

    constructor(bytes32 _merkleRoot, address _royaltyReceiver) ERC721("SomeNFT", "SOME") Ownable(msg.sender) {
        require(_royaltyReceiver != address(0), "Cannot be the zero address");
        merkleRoot = _merkleRoot;
        _setDefaultRoyalty(_royaltyReceiver, ROYALTY_FRACTION);
    }

    function withdrawFunds() external onlyOwner {
        (bool success,) = payable(msg.sender).call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
        emit WithdrawFunds(msg.sender);
    }

    /**
     * @dev mint for users with the discount
     * @param _index Index of the user who has a discount for minting
     */
    function mintWithDiscount(bytes32[] calldata _proof, uint256 _index) external payable nonReentrant whenNotPaused {
        require(msg.value == MINT_PRICE / DISCOUNT_FACTOR, "Incorrect payment amount");
        require(currentSupply < MAX_SUPPLY, "All tokens have been minted");
        require(!BitMaps.get(addressDiscountedMints, _index), "Already minted with discount");
        _verifyMerkleProof(_proof, msg.sender, _index);

        BitMaps.set(addressDiscountedMints, _index);
        _safeMint(msg.sender, currentSupply);
        emit Mint(msg.sender, currentSupply);

        (address receiver, uint256 royaltyAmount) = royaltyInfo(currentSupply, MINT_PRICE / DISCOUNT_FACTOR);
        (bool success,) = payable(receiver).call{value: royaltyAmount}("");
        require(success, "Royalties payment failed");

        //Since we have a max supply, we do not need to worry about overflows
        unchecked {
            currentSupply++;
        }
    }

    function mint() external payable nonReentrant whenNotPaused {
        require(msg.value == MINT_PRICE, "Incorrect payment amount");
        require(currentSupply < MAX_SUPPLY, "All tokens have been minted");

        _safeMint(msg.sender, currentSupply);
        emit Mint(msg.sender, currentSupply);

        (address receiver, uint256 royaltyAmount) = royaltyInfo(currentSupply, MINT_PRICE);
        (bool success,) = payable(receiver).call{value: royaltyAmount}("");
        require(success, "Royalties payment failed");

        //Since we have a max supply, we do not need to worry about overflows
        unchecked {
            currentSupply++;
        }
    }

    /**
     * NFT contracts typically should be allowed to pause and unpause. Either as a safeguard,
     * or to hold off the minting of tokens until a time determined by the owner.
     */
    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    /**
     * @dev checks whether `interfaceId` is equal to `interfaceId` of ERC2981, otherwise calls
     * `super.supportsInterface(interfaceId)` which invokes the `supportsInterface` function of ERC721.
     * Allows to check that ERC2981 and ERC721 are both supported by the contract.
     */
    function supportsInterface(bytes4 interfaceID) public view override(ERC721, ERC2981) returns (bool) {
        return interfaceID == type(ERC2981).interfaceId || super.supportsInterface(interfaceID);
    }

    /**
     * @param _proof Merkle Proof
     * @param _address Address of the user who has a discount
     * @param _index Index of the user
     */
    function _verifyMerkleProof(bytes32[] calldata _proof, address _address, uint256 _index) private view {
        bytes32 leaf = keccak256(abi.encodePacked(_address, _index));
        require(MerkleProof.verify(_proof, merkleRoot, leaf), "Invalid merkle proof");
    }
}
