//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

struct Permit {
    address owner;
    address spender;
    uint256 value;
    uint256 nonce;
    uint256 deadline;
}

contract PermitToken is ERC20Permit {
    
    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) ERC20Permit(name) {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }
}