//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {Nonces} from "@openzeppelin/contracts/utils/Nonces.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Permit.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OrderBook is EIP712, Nonces {
    using SafeERC20 for IERC20;

    IERC20 public tokenA;
    IERC20 public tokenB;

    /**
     * @dev 
     * `maker`: the address that created the order
     * `deadline`: the timestamp after which the order is invalid
     * `nonce`: maker's nonce
     */
    struct Order {
        address maker;
        uint256 deadline;
        address sellToken;
        address buyToken;
        uint256 sellAmount;
        uint256 buyAmount;
        uint256 nonce;
    }

    ///@dev EIP-712 `typehash`
    ///https://eips.ethereum.org/EIPS/eip-712
    bytes32 private constant ORDER_TYPEHASH = keccak256(
        "Order(address maker,uint256 deadline,address sellToken,address buyToken,uint256 sellAmount,uint256 buyAmount,uint256 nonce)"
    );

    constructor(
        address _tokenA,
        address _tokenB
    ) EIP712("OrderBook", "1") {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
    }

    function DOMAIN_SEPARATOR() external view returns (bytes32) {
        return _domainSeparatorV4();
    }

    function permitERC20Token(
        address sellTokenAddr,
        address maker,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        IERC20Permit(sellTokenAddr).permit(
            maker,
            address(this), //`spender` of the allowance
            value,
            deadline,
            v,
            r,
            s
        );
    }


}