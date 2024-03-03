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
        uint112 start_,
        uint112 cliffDuration_,
        uint32 duration_,
        bool revocable_
    ) Ownable(msg.sender) {
        if (beneficiary_ == address(0)) { revert ZeroAddress(); }
        require(cliffDuration_ <= duration_, "TokenVesting: cliff is longer than duration");
        require(duration_ > 0, "TokenVesting: duration is 0");
        require(start_ + duration_ > block.timestamp, "TokenVesting: final time is before current time");

        _setBeneficiaryRevocablePacked(beneficiary_, revocable_);
        _setTimePacked(
            start_ + cliffDuration_,    // cliff_
            start_,                     // start_
            duration_                   // duration_
        );
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

    function released(address token) public view returns (uint256) {
        return _released[token];
    }

    function revoked(address token) public view returns (bool) {
        return _revoked[token];
    }

    /****************************************************************/
    /*                      Authorized Functions                    */
    /****************************************************************/

    function revoke(address _token) external payable onlyOwner {
        if (!revocable()) {
            revert CannotRevoke();
        }
        if (_revoked[_token]) {
            revert AlreadyRevoked();
        }

        uint256 refund = IERC20(_token).balanceOf(address(this)) - _releaseableAmount(_token);
        _revoked[_token] = true;
        IERC20(_token).safeTransfer(msg.sender, refund);
        
        emit TokenVestingRevoked(_token);
    }

    function emergencyRevoke(address _token) external payable onlyOwner {
        if (!revocable()) {
            revert CannotRevoke();
        }
        if (_revoked[_token]) {
            revert AlreadyRevoked();
        }

        uint256 balance = IERC20(_token).balanceOf(address(this));
        _revoked[_token] = true;
        IERC20(_token).safeTransfer(msg.sender, balance);

        emit TokenVestingRevoked(_token);
    }

    /****************************************************************/
    /*                    External/Public Functions                 */
    /****************************************************************/

    function release(address _token) external {
        uint256 unreleased = _releaseableAmount(_token);
        if (unreleased == 0) {
            assembly {
                mstore(0x00, 0x20)
                mstore(0x20, 0x1f)
                mstore(0x40, 0x546f6b656e56657374696e673a206e6f20746f6b656e73206172652064756500)
                revert(0x00, 0x60) //reverts with: "TokenVesting: no tokens are due"
            }
        }
        
        _released[_token] += unreleased;
        IERC20(_token).safeTransfer(beneficiary(), unreleased);
        emit TokensReleased(_token, unreleased);
    }


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

    //Combined original `_releaseableAmount` and `_vestedAmount` functions
    function _releaseableAmount(address _token) private view returns (uint256) {
        //Access once
        uint256 _releasedAmount = _released[_token];

        uint256 currBalance = IERC20(_token).balanceOf(address(this));
        uint256 totalBalance = currBalance + _releasedAmount;

        //Access storage once
        uint256 _timePacked = timePacked;

        //Unpacked packed data
        uint256 _cliff;
        uint256 _start;
        uint256 _duration;
        assembly {
            _cliff := shr(144, shl(144, _timePacked))
            _start := and(shr(112, _timePacked), sub(shl(112, 1), 1))
            _duration := shr(224, _timePacked)
        }

        if (block.timestamp < _cliff) {
            return 0;
        } else if (block.timestamp >= _start + _duration || _revoked[_token]) {
            return totalBalance - _releasedAmount;
        } else {
            return (totalBalance * (block.timestamp - _start) / _duration) - _releasedAmount;
        }
    }

}