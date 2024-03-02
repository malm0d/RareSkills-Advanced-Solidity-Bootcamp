// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TokenVestingOptimized is Ownable {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error CannotRevoke();
    error AlreadyRevoked();

    /****************************************************************/
    /*                            Storage                           */
    /****************************************************************/

    //[0 - 159] `_beneficiary` address
    //[160 - 255] `_revocable` bool
    uint256 private beneficiaryRevocablePacked;

    //[0 - 111] `_cliff` uint112
    //[112 - 223] `_start` uint112
    //[224 - 255] `_duration` uint32
    uint256 private timePacked;

    mapping(address => uint256) private _released;
    mapping(address => bool) private _revoked;

    /****************************************************************/
    /*                            Events                            */
    /****************************************************************/

    event TokensReleased(address token, uint256 amount);
    event TokenVestingRevoked(address token);

    /****************************************************************/
    /*                          Constructor                         */
    /****************************************************************/

    constructor (
        address beneficiary_,
        uint256 start_,
        uint256 cliffDuration_,
        uint256 duration_,
        bool revocable_
    ) Ownable(msg.sender) {

    }

    /****************************************************************/
    /*                         View Functions                       */
    /****************************************************************/

    function beneficiary() public view returns (address addr) {
        assembly {
            addr := shr(96, shl(96, sload(beneficiaryRevocablePacked.slot)))
        }
    }

    function cliff() public view returns (uint256 clf) {
        assembly {
            clf := shr(144, shl(144, sload(timePacked.slot)))
        }
    }

    function start() public view returns (uint256 str) {
        assembly {
            let mask := sub(shl(112, 1), 1)
            str := and(shr(112, sload(timePacked.slot)), mask)
        }
    }

    function duration() public view returns (uint256 dur) {
        assembly {
            dur := shr(224, sload(timePacked.slot))
        }
    }

    function revocable() public view returns (bool rev) {
        assembly {
            rev := shr(160, sload(beneficiaryRevocablePacked.slot))
        }
    }

    /****************************************************************/
    /*                      Authorized Functions                    */
    /****************************************************************/

    /****************************************************************/
    /*                    External/Public Functions                 */
    /****************************************************************/

    /****************************************************************/
    /*                   Internal/Private Functions                 */
    /****************************************************************/

    function _setBeneficiaryRevocablePacked(address _beneficiary, bool _revocable) internal {
        assembly {
            let boolVal := shl(160, _revocable)
            let packed := or(_beneficiary, boolVal)
            sstore(beneficiaryRevocablePacked.slot, packed)
        }
    }

    function _setTimePacked(uint112 _cliff, uint112 _start, uint32 _duration) internal {
        assembly {
            let packed := or(shl(224, _duration), or(shl(112, _start), _cliff))
            sstore(timePacked.slot, packed)
        }
    }

}