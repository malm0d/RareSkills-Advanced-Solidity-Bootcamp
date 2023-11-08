# ERC721A

Link to ERC721A code: https://github.com/chiru-labs/ERC721A/blob/main/contracts/ERC721A.sol
Link to ERC721 code: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC721/ERC721.sol
Link to Yul docs: https://docs.soliditylang.org/en/latest/yul.html

## How does ERC721A save gas?
The article from azuki (https://www.azuki.com/erc721a) is quite self-explanatory. So this page will try to look at the gas savings from a code perspective.

### Packed Storage Variables
ERC721A uses packed storage variables for ownership data and address data. Using a really simple example:

In ERC721:
```
    mapping(uint256 tokenId => address) private _owners;

    mapping(address owner => uint256) private _balances;

    mapping(uint256 tokenId => address) private _tokenApprovals;

    mapping(address owner => mapping(address operator => bool)) private _operatorApprovals;
```

In ERC721A:
```
    struct TokenApprovalRef {
        address value;
    }
    ...

    // Mapping from token ID to ownership details
    // An empty struct value does not necessarily mean the token is unowned.
    // See {_packedOwnershipOf} implementation for details.
    //
    // Bits Layout:
    // - [0..159]   `addr`
    // - [160..223] `startTimestamp`
    // - [224]      `burned`
    // - [225]      `nextInitialized`
    // - [232..255] `extraData`
    mapping(uint256 => uint256) private _packedOwnerships;

    // Mapping owner address to address data.
    //
    // Bits Layout:
    // - [0..63]    `balance`
    // - [64..127]  `numberMinted`
    // - [128..191] `numberBurned`
    // - [192..255] `aux`
    mapping(address => uint256) private _packedAddressData;

    // Mapping from token ID to approved address.
    mapping(uint256 => TokenApprovalRef) private _tokenApprovals;

    // Mapping from owner to operator approvals
    mapping(address => mapping(address => bool)) private _operatorApprovals;
```

ERC721A allows more data to be stored across each 32 bytes (256 bits) storage slot in the `_packedOwnerships` and `_packedAddressData` storage variables, as compared to the `_owners` and `_balances` storage variable in ERC721. 

To further expand on this, an `address` in solidity is 40 hexadecimal characters, which is equivalent to 20 bytes (160 bits). So for each storage slot in the `_packedOwnership` mapping, an address will be packed into the first 160 bits to effectively allow the remaining 96 bits in the same slot to be used for other data. The same methodology is applied to the `packedAddressData` as well. If we extend this to the storage variables in ERC721, it's quite obvious that each storage slot in the mappings have a lot of under-utilized bit space.

By packing multiple data values into a single slot, the number of storage read and writes (cold and warm) are greatly reduced and this can save a lot of gas.

### Removing unnecessary overflow and underflow checks, and bitwise operations
Many functions in ERC721 carry out unnecessary overflow and underflow checks, for example, a user's balance or the number of NFT in circulation would never exceed 2**256. ERC721A addresses these unncessary operations by introducing many `unchecked` blocks. ERC721A also uses bitwise operations to perform updates on data, which is alot cheaper and efficient at modifying packed storage variables. An example of this is illustrated in ERC721A's `_mint` function:

```
/**
     * @dev Mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     * - `quantity` must be greater than 0.
     *
     * Emits a {Transfer} event for each mint.
     */
    function _mint(address to, uint256 quantity) internal virtual {
        uint256 startTokenId = _currentIndex;
        if (quantity == 0) _revert(MintZeroQuantity.selector);

        _beforeTokenTransfers(address(0), to, startTokenId, quantity);

        // Overflows are incredibly unrealistic.
        // `balance` and `numberMinted` have a maximum limit of 2**64.
        // `tokenId` has a maximum limit of 2**256.
        unchecked {
            // Updates:
            // - `address` to the owner.
            // - `startTimestamp` to the timestamp of minting.
            // - `burned` to `false`.
            // - `nextInitialized` to `quantity == 1`.
            _packedOwnerships[startTokenId] = _packOwnershipData(
                to,
                _nextInitializedFlag(quantity) | _nextExtraData(address(0), to, 0)
            );

            // Updates:
            // - `balance += quantity`.
            // - `numberMinted += quantity`.
            //
            // We can directly add to the `balance` and `numberMinted`.
            _packedAddressData[to] += quantity * ((1 << _BITPOS_NUMBER_MINTED) | 1);

            // Mask `to` to the lower 160 bits, in case the upper bits somehow aren't clean.
            uint256 toMasked = uint256(uint160(to)) & _BITMASK_ADDRESS;

            if (toMasked == 0) _revert(MintToZeroAddress.selector);

            uint256 end = startTokenId + quantity;
            uint256 tokenId = startTokenId;

            do {
                assembly {
                    // Emit the `Transfer` event.
                    log4(
                        0, // Start of data (0, since no data).
                        0, // End of data (0, since no data).
                        _TRANSFER_EVENT_SIGNATURE, // Signature.
                        0, // `address(0)`.
                        toMasked, // `to`.
                        tokenId // `tokenId`.
                    )
                }
                // The `!=` check ensures that large values of `quantity`
                // that overflows uint256 will make the loop run out of gas.
            } while (++tokenId != end);

            _currentIndex = end;
        }
        _afterTokenTransfers(address(0), to, startTokenId, quantity);
    }
```
Note that the value for `_BITPOS_NUMBER_MINTED` is `64`. So in the line `_packedAddressData[to] += quantity * ((1 << _BITPOS_NUMBER_MINTED) | 1);`, ERC721A efficiently packs the `balance` into the first `64` bits of the slot; and then packs the `numberMinted` into the next `64` bits by first performing `(1 << 64)` which shifts 1 by 64 positions to the left, and then performs an `OR` operation to set the 65th bit to 1, which is then multiplied by the quantity of tokens to be minted. (Theres a bit more to the `OR` operation regarding setting the least significant bit to 1).

All of such operations in ERC721A will add up to help save gas.

### Consecutive Minting (ERC2309)
ERC721A has a `_mintERC2309` function that allows multiple tokens to be minted to a single address (during contract creation). Essentially when a bulk of tokens are to be minted, this function can be used to emit a single `ConsecutiveTransfer` event instead of multiple `Transfer` events to reduce gas usage

## Where does ERC721A add costs?
ERC721A's `_safeMint` function has added costs. In the function:
```
    /**
     * @dev Safely mints `quantity` tokens and transfers them to `to`.
     *
     * Requirements:
     *
     * - If `to` refers to a smart contract, it must implement
     * {IERC721Receiver-onERC721Received}, which is called for each safe transfer.
     * - `quantity` must be greater than 0.
     *
     * See {_mint}.
     *
     * Emits a {Transfer} event for each mint.
     */
    function _safeMint(
        address to,
        uint256 quantity,
        bytes memory _data
    ) internal virtual {
        _mint(to, quantity);

        unchecked {
            if (to.code.length != 0) {
                uint256 end = _currentIndex;
                uint256 index = end - quantity;
                do {
                    if (!_checkContractOnERC721Received(address(0), to, index++, _data)) {
                        _revert(TransferToNonERC721ReceiverImplementer.selector);
                    }
                } while (index < end);
                // Reentrancy protection.
                if (_currentIndex != end) _revert(bytes4(0));
            }
        }
    }

    *********Additional check if recipient of _safeMint is a contract*********

    /**
     * @dev Private function to invoke {IERC721Receiver-onERC721Received} on a target contract.
     *
     * `from` - Previous owner of the given token ID.
     * `to` - Target address that will receive the token.
     * `tokenId` - Token ID to be transferred.
     * `_data` - Optional data to send along with the call.
     *
     * Returns whether the call correctly returned the expected magic value.
     */
    function _checkContractOnERC721Received(
        address from,
        address to,
        uint256 tokenId,
        bytes memory _data
    ) private returns (bool) {
        try ERC721A__IERC721Receiver(to).onERC721Received(_msgSenderERC721A(), from, tokenId, _data) returns (
            bytes4 retval
        ) {
            return retval == ERC721A__IERC721Receiver(to).onERC721Received.selector;
        } catch (bytes memory reason) {
            if (reason.length == 0) {
                _revert(TransferToNonERC721ReceiverImplementer.selector);
            }
            assembly {
                revert(add(32, reason), mload(reason))
            }
        }
    }
```
It does a check to see if the `to` address is an EOA or contract. And if it is a contract, if performs an additional check to ensure that the call does not revert, and that the receiving contract has the expected "magic value" which is basically the function selector (4 bytes) for the `onERC721Received` function.

This article (https://www.rareskills.io/post/erc721#viewer-cucj0) explains the importance of checking for the function selector, but basically, if the call did not revert, its not enough to ensure that the receipient contract can handle the ERC721 (and ERC721A and all its siblings) tokens. If the recipient contract has a `fallback` function and the magic value is not checked for, then the transaction WILL NOT revert and the ERC721 token will be stuck (serious vulnerability we want to avoid).

