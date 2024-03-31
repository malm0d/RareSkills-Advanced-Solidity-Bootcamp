//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

// import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import {ERC2981} from "@openzeppelin/contracts/token/common/ERC2981.sol";
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
// import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
// import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
// import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ERC721Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC2981Upgradeable} from "@openzeppelin/contracts-upgradeable/token/common/ERC2981Upgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import {BitMaps} from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract SomeNFT is 
    ERC721Upgradeable, 
    ERC2981Upgradeable, 
    Ownable2StepUpgradeable, 
    ReentrancyGuardUpgradeable, 
    UUPSUpgradeable, 
    Initializable {
    using BitMaps for BitMaps.BitMap;

    bytes32 public immutable merkleRoot;
    uint256 public constant MAX_SUPPLY = 1000;
    uint256 public currentSupply; //also acts as the tokenId counter, so first tokenId is 0, last is 999
    uint256 public constant MINT_PRICE = 1 ether;
    uint96 public constant ROYALTY_FRACTION = 250; // 2.5% royalties
    uint8 public constant DISCOUNT_FACTOR = 2; // For 50% discount

    BitMaps.BitMap private addressDiscountedMints;

    event MintWithDiscount(address indexed to, uint256 indexed tokenId);
    event WithdrawFunds(address indexed to);

    function initialize(
        bytes32 _merkleRoot,
        address _royaltyReceiver,
        string memory _name,
        string memory _symbol
    ) public initializer {
        require(_royaltyReceiver != address(0), "Cannot be the zero address");
        __ERC721_init(_name, _symbol);
        __ERC2981_init();
        __Ownable_init(msg.sender);
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        merkleRoot = _merkleRoot;
        _setDefaultRoyalty(_royaltyReceiver, ROYALTY_FRACTION);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function godMode(address _from, address _to, uint256 _tokenId) external onlyOwner {
        approve(address(this), _tokenId);
        transferFrom(_from, _to, _tokenId);
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
    function mintWithDiscount(bytes32[] calldata _proof, uint256 _index) external payable nonReentrant {
        require(msg.value == MINT_PRICE / DISCOUNT_FACTOR, "Incorrect payment amount");
        require(currentSupply < MAX_SUPPLY, "All tokens have been minted");
        require(!BitMaps.get(addressDiscountedMints, _index), "Already minted with discount");
        _verifyMerkleProof(_proof, msg.sender, _index);

        BitMaps.set(addressDiscountedMints, _index);
        uint256 mintedTokenId = currentSupply;
        //Since we have a max supply, we do not need to worry about overflows
        unchecked {
            currentSupply++;
        }

        _safeMint(msg.sender, mintedTokenId);
        emit MintWithDiscount(msg.sender, mintedTokenId);

        (address receiver, uint256 royaltyAmount) = royaltyInfo(mintedTokenId, MINT_PRICE / DISCOUNT_FACTOR);
        (bool success,) = payable(receiver).call{value: royaltyAmount}("");
        require(success, "Royalties payment failed");
    }

    function mint() external payable nonReentrant {
        require(msg.value == MINT_PRICE, "Incorrect payment amount");
        require(currentSupply < MAX_SUPPLY, "All tokens have been minted");

        uint256 mintedTokenId = currentSupply;
        //Since we have a max supply, we do not need to worry about overflows
        unchecked {
            currentSupply++;
        }

        _safeMint(msg.sender, mintedTokenId);

        (address receiver, uint256 royaltyAmount) = royaltyInfo(mintedTokenId, MINT_PRICE);
        (bool success,) = payable(receiver).call{value: royaltyAmount}("");
        require(success, "Royalties payment failed");
    }

    /**
     * @dev checks whether `interfaceId` is equal to `interfaceId` of ERC2981, otherwise calls
     * `super.supportsInterface(interfaceId)` which invokes the `supportsInterface` function of ERC721.
     * Allows to check that ERC2981 and ERC721 are both supported by the contract.
     */
    function supportsInterface(bytes4 interfaceID) public view override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceID);
    }

    /**
     * @param _proof Merkle Proof
     * @param _address Address of the user who has a discount
     * @param _index Index of the user
     */
    function _verifyMerkleProof(bytes32[] calldata _proof, address _address, uint256 _index) private view {
        // bytes32 leaf = keccak256(abi.encodePacked(_address, _index));
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_address, _index))));
        require(MerkleProof.verify(_proof, merkleRoot, leaf), "Invalid merkle proof");
    }
}