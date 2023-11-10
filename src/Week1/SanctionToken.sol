// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract SanctionToken is ERC20, Ownable2Step {
    using SafeERC20 for ERC20;

    mapping(address => bool) public sanctionList;

    event BanAccount(address indexed _address);
    event UnbanAccount(address indexed _address);

    constructor(uint256 _initialSupply) ERC20("SanctionToken", "ST") Ownable(msg.sender) {
        _mint(msg.sender, _initialSupply);
    }

    function banAddress(address _address) external onlyOwner {
        require(!sanctionList[_address], "Address is already banned");
        sanctionList[_address] = true;

        emit BanAccount(_address);
    }

    function unbanAddress(address _address) external onlyOwner {
        require(sanctionList[_address], "Address is not banned");
        sanctionList[_address] = false;

        emit UnbanAccount(_address);
    }

    function mint(address _to, uint256 _amount) external {
        require(_amount > 0, "Cannot mint zero tokens");
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external {
        require(_amount > 0, "Cannot burn zero tokens");
        _burn(_from, _amount);
    }

    /**
     * @dev Overrides ERC20's _update function by introducing a check to see if the `from` or `to` address are
     * in the sanctionList. If they are, it will revert.
     * FYI: ERC20's `_beforeTokenTransfer` and `_afterTokenTransfer` have been replaced with `_update` in v5.x
     * The _update function is called by the _transfer, _transferFrom, _mint, _burn, functions of ERC20.
     */
    function _update(address from, address to, uint256 value) internal override {
        require(!sanctionList[from], "Sender is sanctioned");
        require(!sanctionList[to], "Recipient is sanctioned");
        super._update(from, to, value);
    }
}
