//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {IERC721} from "@openzeppelin/contracts/interfaces/IERC721.sol";
import {IERC721Enumerable} from "@openzeppelin/contracts/interfaces/IERC721Enumerable.sol";
import {SomeNFTEnumerable} from "./SomeNFTEnumerable.sol";

contract IsPrimeOnSteroids {
    address public someEnumerableAddress;

    constructor(address _someNFTEnummerable) payable {
        someEnumerableAddress = _someNFTEnummerable;
    }

    // _ownedTokens -> { address: { index: tokenId, ...}, ... }
    // Use staticcall because this is a view function
    function countPrimes(address _owner) external view returns (uint256) {
        uint256 count;
        assembly {
            let _a := sload(someEnumerableAddress.slot)
            let memPointer := mload(0x40) //free memory pointer - where we write to memory
            let oldMemPointer := memPointer
            mstore(memPointer, 0x70a08231) //function selector: balanceOf(address")
            mstore(add(memPointer, 0x20), _owner) //address argument
            mstore(0x40, add(memPointer, 0x40)) //advance by 2 x 32 bytes
            let success := staticcall(gas(), _a, add(oldMemPointer, 28), mload(0x40), 0x00, 0x20)
            if iszero(success) { revert(0, 0) }
            count := mload(0x00)
        }
        uint256 result = 0;
        for (uint256 i = 0; i < count; i++) {
            uint256 tokenId;
            assembly {
                let _a := sload(someEnumerableAddress.slot)
                let mPointer := mload(0x40)
                let oldMPointer := mPointer
                mstore(mPointer, 0x2f745c59) //function selector: tokenOfOwnerByIndex(address, uint256)
                mstore(add(mPointer, 0x20), _owner) //address argument
                mstore(add(mPointer, 0x40), i) //index argument
                mstore(0x40, add(mPointer, 0x60)) //advance by 3 x 32 bytes
                let s := staticcall(gas(), _a, add(oldMPointer, 28), mload(0x40), 0x00, 0x20)
                if iszero(s) { revert(0, 0) }
                tokenId := mload(0x00)
            }
            if (_isPrimeNumber(tokenId)) {
                result++;
            }
        }
        return result;
    }

    // Its easier and more practical to do this in Solidity...
    function _isPrimeNumber(uint256 n) public pure returns (bool) {
        if (n < 2) {
            return false;
        }

        if (n < 4) {
            return true;
        }

        if (n % 2 == 0) {
            return false;
        }

        if (n % 3 == 0) {
            return false;
        }

        /**
         * Check divisibility for numbers of form 6k +- 1 up to sqrt of n.
         * Based from: https://en.wikipedia.org/wiki/Primality_test
         */
        for (uint256 i = 5; i * i <= n;) {
            if (n % i == 0) {
                return false;
            }

            if (n % (i + 2) == 0) {
                return false;
            }
            unchecked {
                i += 6;
            }
        }

        return true;
    }
}
