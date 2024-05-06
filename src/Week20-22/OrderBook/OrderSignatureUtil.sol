//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {Order, OrderBook} from "src/Week20-22/OrderBook/OrderBook.sol";

contract OrderSignatureUtil is Test {

    /// We dont need to cast with `bytes` if we are using a string literal as in:
    /// bytes32 private constant ORDER_TYPEHASH = keccak256("Order(address maker,...,uint256 nonce)");
    /// Also we are dealing only with native types. Refer to RS notes or the following example at
    /// https://github.com/flood-protocol/flood-contracts/blob/master/src/libraries/OrderHash.sol
    /// for complex nested custom types.
    string internal constant _ORDER_STRING = "Order(address maker,uint256 deadline,address sellToken,address buyToken,uint256 sellTokenAmount,uint256 buyTokenAmount,uint256 nonce)";
    string internal constant _PERMIT_STRING = "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)";
    bytes32 internal constant _ORDER_TYPEHASH = keccak256(bytes(_ORDER_STRING));
    bytes32 internal constant _PERMIT_TYPEHASH = keccak256(bytes(_PERMIT_STRING));

    /// @dev EIP712: `hashStruct` function to calculate hash of struct
    /// keccak256(abi.encode(typeHash, encodeData(struct)))
    function getOrderStructHash(Order memory _order) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            _ORDER_TYPEHASH,
            _order.maker,
            _order.deadline,
            _order.sellToken,
            _order.buyToken,
            _order.sellTokenAmount,
            _order.buyTokenAmount,
            _order.nonce
        ));
    }

    /// @dev EIP712: calculate the hash of fully encoded EIP712 message.
    /// "\x19\x01" ‖ domainSeparator ‖ structHash
    function hashAsMessage(bytes32 _domainSeparator, Order memory _order) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            "\x19\x01",
            _domainSeparator,
            getOrderStructHash(_order)
        ));
    }

    function getSignature() public pure returns (bytes memory) {}

}