//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {RewardToken} from "./RewardToken.sol";
import {SomeNFT} from "./SomeNFT.sol";

/**
 * Other notes, packing in this contract can also be done with a struct instead of handling bits:
 *
 * struct StakingInfo {
 *     address owner;
 *     uint86 claimTime;
 * }
 * mapping(uint256 => StakingInfo) public stakingInfo;
 *
 * This would still be packing the data, but we use a struct to make it easier for us to handle data.
 * Through this, we can also utilize the `delete` keyword to clear the struct data.
 */

/**
 * The contract becomes the owner of the NFT when it is staked
 * Users can stake NFT and receive 10 RTs per day (24h)
 * Users can unstake their NFT anytime
 */
contract StakingNFT is IERC721Receiver, Ownable2Step, ReentrancyGuard, Pausable {
    /**
     * @dev The mask of the lower 160 bits for addresses.
     * 0x00000000000000000000000000000000000000000000000000000000ffffffffffffffffffffffffffffffffffffffff
     */
    uint256 private constant _BITMASK_ADDRESS = (1 << 160) - 1;

    /**
     * @dev The bit position of `claimTime` in packed stakingInfo.
     */
    uint256 private constant _BITPOS_START_TIMESTAMP = 160;

    SomeNFT public someNFTContract;
    RewardToken public rewardTokenContract;
    uint256 public constant interval = 1 days; //fixed
    uint256 public constant MINT_AMOUNT = 10 * (10 ** 18); //10 RTs

    /**
     * @dev maps token id to staking information
     * Bits layout:
     * - [0 - 159] `address` of the original owner of the NFT
     * - [160 - 255] `claimTime` timestamp for claiming staking rewards
     */
    mapping(uint256 => uint256) public stakingInfo;

    event StakedNFT(address indexed staker, uint256 indexed tokenId);
    event WithdrawNFT(address indexed staker, uint256 indexed tokenId);
    event MintRewards(address indexed staker, uint256 amount);

    constructor(address _someNFT, address _rewardToken) Ownable(msg.sender) {
        someNFTContract = SomeNFT(_someNFT);
        rewardTokenContract = RewardToken(_rewardToken);
    }

    function onERC721Received(
        address, /*operator*/
        address from,
        uint256 tokenId,
        bytes calldata /*data*/
    )
        external
        returns (bytes4)
    {
        /**
         * @dev Called at the end of the `safeTransferFrom` function in the ERC721 contract.
         * The msg.sender will be the ERC721 contract, NOT the owner of the token,
         * as the ERC721 contract itself will call this function when `_checkOnERC721Received` is called
         * in the execution of the `safeTransferFrom` function (fyi: also during _safeMint).
         *
         * IMPORTANT: Check that the msg.sender is the ERC721 contract
         * Accept the token only if condition is satisfied, otherwise we must revert.
         * See the `testTransferNFTFail` test in `Staking.t.sol`.
         */
        require(msg.sender == address(someNFTContract), "Caller is not the ERC721 contract");
        stakingInfo[tokenId] = _packStakingData(from);
        emit StakedNFT(msg.sender, tokenId);
        return IERC721Receiver.onERC721Received.selector;
    }

    /**
     * @dev Updates the packed stakingInfo
     */
    function _packStakingData(address _owner) private view returns (uint256 result) {
        assembly {
            //mask owner to lower 160 bits
            _owner := and(_owner, _BITMASK_ADDRESS)
            //`owner` | (block.timestamp << 160)
            result := or(_owner, shl(_BITPOS_START_TIMESTAMP, timestamp()))
        }
    }

    /**
     * @dev `safeTransferFrom` handles the ownership check and clearing the approval when
     * the transfer was successful (see `transferFrom` and `_update`). We do not need to do that here.
     * The checking of the trusted ERC721 contract and a valid token ID is done in `onERC721Received`.
     * This function ASSUMES that approval has already been granted, so it will revert if it has not.
     *
     * Note: This function is not strictly necessary, as we can just safe transfer to this contract for staking.
     * The `safeTransferFrom` is called directly from the NFT contract, so an extra function here is not needed.
     */
    // function stakeNFT(uint256 _tokenId) external nonReentrant whenNotPaused {
    //     someNFTContract.safeTransferFrom(msg.sender, address(this), _tokenId);
    //     emit StakedNFT(msg.sender, _tokenId);
    // }

    /**
     * @dev if the user has not claimed since the last 24 hours by the time they withdraw, they will be given
     * the staking rewards for the last 24 hours. This is to prevent users from withdrawing and staking.
     */
    function withdrawNFT(uint256 _tokenId) external nonReentrant whenNotPaused {
        require(msg.sender == getOriginalOwner(_tokenId), "Only the original owner can withdraw");

        if (!(block.timestamp - getClaimTime(_tokenId) < interval)) {
            rewardTokenContract.mintRewards(msg.sender, MINT_AMOUNT);
            emit MintRewards(msg.sender, MINT_AMOUNT);
        }

        //set the claimTime bits to 0
        //THIS MUST BE SET TO ZERO TO PREVENT REENTRANCY ATTACKS.
        stakingInfo[_tokenId] = 0;

        someNFTContract.safeTransferFrom(address(this), msg.sender, _tokenId);

        emit WithdrawNFT(msg.sender, _tokenId);
    }

    /**
     * @dev This function requires the token id. But in reality this might not be a practical design,
     * as it assumes that the dApp has a way to remember which token id was staked by each user.
     * Only can claim once every 24 hours
     */
    function claimRewards(uint256 _tokenId) external nonReentrant whenNotPaused {
        require(getClaimTime(_tokenId) > 0, "This token ID is not staked");
        require(msg.sender == getOriginalOwner(_tokenId), "Only the original owner can claim rewards for this token ID");
        require(!(block.timestamp - getClaimTime(_tokenId) < interval), "Can only claim after every 24 hours");

        //update the claimTime bits to the current timestamp
        stakingInfo[_tokenId] = _packStakingData(msg.sender);
        rewardTokenContract.mintRewards(msg.sender, MINT_AMOUNT);

        emit MintRewards(msg.sender, MINT_AMOUNT);
    }

    function pause() external whenNotPaused onlyOwner {
        _pause();
    }

    function unpause() external whenPaused onlyOwner {
        _unpause();
    }

    function getOriginalOwner(uint256 _tokenId) public view returns (address) {
        address owner = address(uint160(stakingInfo[_tokenId] & _BITMASK_ADDRESS));
        return owner;
    }

    function getClaimTime(uint256 _tokenId) public view returns (uint256) {
        return (stakingInfo[_tokenId] >> _BITPOS_START_TIMESTAMP);
    }
}
