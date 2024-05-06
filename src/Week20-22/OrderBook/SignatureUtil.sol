//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {Permit} from "src/Week20-22/OrderBook/PermitToken.sol";
import {Order, OrderBook} from "src/Week20-22/OrderBook/OrderBook.sol";

contract SignatureUtil is Test {

    /// We dont need to cast with `bytes` if we are using a string literal as in:
    /// bytes32 private constant ORDER_TYPEHASH = keccak256("Order(address maker,...,uint256 nonce)");
    /// Also we are dealing only with native types. Refer to RS notes or the following example at
    /// https://github.com/flood-protocol/flood-contracts/blob/master/src/libraries/OrderHash.sol
    /// for complex nested custom types.
    string internal constant _ORDER_STRING = "Order(address maker,uint256 deadline,address sellToken,address buyToken,uint256 sellTokenAmount,uint256 buyTokenAmount,uint256 nonce)";
    string internal constant _PERMIT_STRING = "Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)";
    bytes32 internal constant _ORDER_TYPEHASH = keccak256(bytes(_ORDER_STRING));
    bytes32 internal constant _PERMIT_TYPEHASH = keccak256(bytes(_PERMIT_STRING));

    /***********************************************************/
    /*                          Order                          */
    /***********************************************************/

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
    function hashOrderAsMessage(bytes32 _domainSeparator, Order memory _order) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            "\x19\x01",
            _domainSeparator,
            getOrderStructHash(_order)
        ));
    }

    /// @dev Signs the message, and returns the signature which is the concatenation of r, s, and v.
    /// vm.sign(uint256 privateKey, bytes32 digest) -> (uint8 v, bytes32 r, bytes32 s)
    function getOrderSignature(
        bytes32 _domainSeparator,
        Order memory _order,
        uint256 _privateKey
    ) public pure returns (bytes memory) {
        bytes32 msgHash = hashOrderAsMessage(_domainSeparator, _order);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, msgHash);

        //return concatenation
        return bytes.concat(r, s, bytes1(v));
    }

    /************************************************************/
    /*                          Permit                          */
    /************************************************************/

    function getPermitStructHash(Permit memory _permit) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            _PERMIT_TYPEHASH,
            _permit.owner,
            _permit.spender,
            _permit.value,
            _permit.nonce,
            _permit.deadline
        ));
    }

    function hashPermitAsMessage(bytes32 _domainSeparator, Permit memory _permit) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(
            "\x19\x01",
            _domainSeparator,
            getPermitStructHash(_permit)
        ));
    }

    function getPermitSignature(
        bytes32 _domainSeparator,
        Permit memory _permit,
        uint256 _privateKey
    ) public pure returns (bytes memory) {
        bytes32 msgHash = hashPermitAsMessage(_domainSeparator, _permit);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_privateKey, msgHash);

        //return concatenation
        return bytes.concat(r, s, bytes1(v));
    }

}