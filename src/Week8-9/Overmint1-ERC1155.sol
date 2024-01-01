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

contract ExploitContract is ERC1155Holder {
    Overmint1_ERC1155 public overmint1_ERC1155;

    constructor(Overmint1_ERC1155 _overmint1_ERC1155) {
        overmint1_ERC1155 = _overmint1_ERC1155;
    }

    function attack() public {}
}
