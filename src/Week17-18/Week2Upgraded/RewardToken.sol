//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
// import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract RewardToken is ERC20Upgradeable, Ownable2StepUpgradeable, UUPSUpgradeable, Initializable {
    address public stakingContract;

    function initialize() public initializer {
        __ERC20_init("RewardToken", "RT");
        __Ownable_init(msg.sender);
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function updateStakingContract(address _stakingContractAddress) external onlyOwner {
        require(_stakingContractAddress != address(0), "Cannot be the zero address");
        stakingContract = _stakingContractAddress;
    }

    function mintRewards(address _to, uint256 _amount) external {
        require(msg.sender == stakingContract, "Only staking contract can mint rewards");
        _mint(_to, _amount);
    }
}
