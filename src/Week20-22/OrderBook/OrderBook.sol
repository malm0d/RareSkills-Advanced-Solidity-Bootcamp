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

    error SignatureExpired();
    error InvalidSignature();
    error InvalidSignatureLength();
    error OrderMismatch();
    error PermitOrderMismatch();

    event MatchedOrderExecuted();

    IERC20 public tokenA;
    IERC20 public tokenB;

    /**
     * @dev 
     * `maker`: the address that created the order
     * `deadline`: the timestamp after which the order is invalid
     * `nonce`: maker's nonce
     *
     * Every Order will have a sell and buy amount, since
     * since an order is a trade of two tokens.
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

    struct Permit {
        address tokenAddr;
        address owner; //`owner` of the tokens
        uint256 value;
        uint256 deadline;
        uint8 v;
        bytes32 r;
        bytes32 s;

    }

    ///@dev EIP-712 `typehash`: keccak256(encodeType(typeOf(struct)))
    ///https://eips.ethereum.org/EIPS/eip-712
    //keccak256(bytes(String))?
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

    function executeMatchedOrder(
        Permit memory sellPermit,
        Order memory sellOrder,
        bytes memory sellSignature,
        Permit memory buyPermit,
        Order memory buyOrder,
        bytes memory buySignature
    ) external {
        //Validate signatures
        {
            (bytes32 r_Sell, bytes32 s_Sell, uint8 v_Sell) = _splitSignature(sellSignature);
            _validateSignature(sellOrder, r_Sell, s_Sell, v_Sell);

            (bytes32 r_Buy, bytes32 s_Buy, uint8 v_Buy) = _splitSignature(buySignature);
            _validateSignature(buyOrder, r_Buy, s_Buy, v_Buy);
        }

        //Check orders and ratio
        _checkOrdersAndRatio(sellOrder, buyOrder);

        //Permit and order match are needed for both sell and buy orders
        //since funds are being transferred in both directions
        _chcekPermitAndOrderMatch(sellPermit, sellOrder);
        _chcekPermitAndOrderMatch(buyPermit, buyOrder);

        //Execute the permits
        _permitERC20(
            sellPermit.tokenAddr, 
            sellPermit.owner, 
            sellPermit.value, 
            sellPermit.deadline, 
            sellPermit.v, 
            sellPermit.r, 
            sellPermit.s
        );

        _permitERC20(
            buyPermit.tokenAddr, 
            buyPermit.owner, 
            buyPermit.value, 
            buyPermit.deadline, 
            buyPermit.v, 
            buyPermit.r, 
            buyPermit.s
        );

        //Move tokens from both parties
        _executeTrade(sellOrder, buyOrder);   

        emit MatchedOrderExecuted();
    }

    function _executeTrade(
        Order memory orderA,
        Order memory orderB
    ) internal {
        //Calculate the amount to swap
        uint256 amountTokenA;
        uint256 amountTokenB;
        {
            //If Order A is willing to sell more than Order B is willing to buy, then we swap
            //based on the amount Order B is willing to buy (the smaller buy amount), so Order B
            //does not exceed its stated buy amount.
            //
            //Else, if Order A is willing to sell less than or equal to Order B is willing to buy,
            //then we swap based on the amount Order A is willing to buy (the larger buy amount), so
            //Order A does not exceed its stated buy amount.
            if (orderA.sellAmount > orderB.buyAmount) {
                amountTokenB = orderB.buyAmount;     //the max Order B is willing to buy
                amountTokenA = orderB.sellAmount;    //the amount Order B is willing to sell
            } else {
                amountTokenA = orderA.buyAmount;     //the max Order A is willing to buy
                amountTokenB = orderA.sellAmount;    //the amount Order A is willing to sell
            }
        }

        //Transfer tokens
        tokenA.safeTransferFrom(orderA.maker, orderB.maker, amountTokenB);
    }

    function _validateSignature(
        Order memory _order,
        bytes32 r,
        bytes32 s,
        uint8 v
    ) internal {
        if (_order.deadline < block.timestamp) {
            revert SignatureExpired();
        }

        //EIP712: `encodeData(struct)`
        bytes32 structHash = keccak256(abi.encode(
            ORDER_TYPEHASH,
            _order.maker,
            _order.deadline,
            _order.sellToken,
            _order.buyToken,
            _order.sellAmount,
            _order.buyAmount,
            _useNonce(_order.maker)
        ));

        //EIP712: hash of fully encoded message
        //Using `_hashTypedDataV4` from O.Z will calculate the hash of the fully encoded message
        //according to standard with: "\x19\x01" ‖ domainSeparator ‖ hashStruct(message)
        bytes32 hash = _hashTypedDataV4(structHash);

        //Recover Signer address with ECDSA (O.Z.)
        //Avoid using ecrecover directly for malleability reasons
        address signer = ECDSA.recover(hash, v, r, s);
        if (signer != _order.maker) {
            revert InvalidSignature();
        }
    }

    function _splitSignature(
        bytes memory _signature
    ) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        if (_signature.length != 65) {
            revert InvalidSignatureLength();
        }

        //First 32 bytes is the length of the bytes array.
        //So: add(_signature, 0x20) = pointer of signature + 32 bytes,
        //i.e. the start of `r` (and the actual signature itself).
        assembly {
            //First 32 bytes after length prefix is `r`.
            //Next 32 bytes is `s`.
            //Last byte is `v`.
            r := mload(add(_signature, 0x20))
            s := mload(add(_signature, 0x40))

            //Extract the most significant byte of the last 32 bytes (`v`)
            ///byte(n, x): extract the nth byte of x (n is the position of the byte in x)
            //where 0 is the most significant byte (leftmost)
            v := byte(0, mload(add(_signature, 0x60)))
        }
    }

    ///@dev the `owner` of the permit must be the `maker` of the order.
    ///Owner of the permit creates a signature that allows the `spender` to spend its tokens
    ///when an order(trade) is created. In this context, the `spender` is the `OrderBook` contract.
    ///Ensures that the address that created the permit is dealing with an order it created.
    function _chcekPermitAndOrderMatch (
        Permit memory permit,
        Order memory order
    ) internal pure {
        if (permit.owner != order.maker) {
            revert PermitOrderMismatch();
        }
    }

    ///@dev the `sellToken` of one order must be the `buyToken` of the other
    //and the `sellAmount` and `buyAmount` must be more than zero (cannot buy and sell for nothing).
    //Also need to check the raio so that a malicious actor cannot create and execute orders with
    //imbalanced ratios, causing one party to receive significantly more tokens for the trade.
    function _checkOrdersAndRatio (
        Order memory orderA,
        Order memory orderB
    ) internal pure {
        require(orderA.sellToken == orderB.buyToken, "Wrong token pair");
        require(orderA.buyToken == orderB.sellToken, "Wrong token pair");
        require(orderA.sellAmount > 0, "Zero sell amount");
        require(orderB.buyAmount > 0, "Zero buy amount");
        require(orderA.buyAmount > 0, "Zero buy amount");
        require(orderB.sellAmount > 0, "Zero sell amount");

        //If sell and buy amounts for first order is equal, then the second must follow suit
        if (orderA.sellAmount == orderA.buyAmount) {
            require(orderB.sellAmount == orderB.buyAmount, "Ratio mismatch");
        } else if (orderA.sellAmount > orderA.buyAmount) {
            uint256 ratioOrderA = orderA.sellAmount / orderA.buyAmount;
            uint256 ratioOrderB = orderB.buyAmount / orderB.sellAmount;
            require(ratioOrderA == ratioOrderB, "Ratio mismatch");
        } else {
            uint256 ratioOrderA = orderA.buyAmount / orderA.sellAmount;
            uint256 ratioOrderB = orderB.sellAmount / orderB.buyAmount;
            require(ratioOrderA == ratioOrderB, "Ratio mismatch");
        }
    }

    ///@dev executes ERC20Permit `permit`
    function _permitERC20(
        address tokenAddr,
        address owner,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) internal {
        IERC20Permit(tokenAddr).permit(
            owner, //`owner` of the tokens
            address(this), //`spender` of the allowance
            value,
            deadline,
            v,
            r,
            s
        );
    }
}