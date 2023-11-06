// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC1363} from "./ERC1363.sol";

contract MockERC1363 is ERC1363 {
    constructor() ERC20("MockERC20", "ME20") {
        _mint(msg.sender, 1000000000e18);
    }

    function mint(address account, uint256 amount) external {
        _mint(account, amount);
    }

    function burn(address account, uint256 amount) external {
        _burn(account, amount);
    }
}
