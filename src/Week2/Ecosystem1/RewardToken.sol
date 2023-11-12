//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

contract RewardToken is ERC20, Ownable2Step {
    using SafeERC20 for ERC20;

    address public stakingContract;

    constructor(address _stakingContract) ERC20("RewardToken", "RT") Ownable(msg.sender) {
        stakingContract = _stakingContract;
    }

    function updateStakingContract(address _stakingContractAddress) external onlyOwner {
        require(_stakingContractAddress != address(0), "Cannot be the zero address");
        stakingContract = _stakingContractAddress;
    }

    function mintRewards(address _to, uint256 _amount) external {
        require(msg.sender == stakingContract, "Only staking contract can mint rewards");
        _mint(_to, _amount);
    }

    function mintToOwner(uint256 _amount) external onlyOwner {
        _mint(msg.sender, _amount);
    }
}
