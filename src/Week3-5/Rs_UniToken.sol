//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC20} from "@solady/src/tokens/ERC20.sol";

contract UniToken is ERC20 {
    string private _name = "UniToken";
    string private _symbol = "UT";

    constructor() {}

    function name() public view override returns (string memory) {
        return _name;
    }

    function symbol() public view override returns (string memory) {
        return _symbol;
    }
}
