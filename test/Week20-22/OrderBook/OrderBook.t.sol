//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console, console2} from "forge-std/Test.sol";
import {PermitToken, Permit} from "src/Week20-22/OrderBook/PermitToken.sol";
import {OrderBook, Order, PermitWithVRS} from "src/Week20-22/OrderBook/OrderBook.sol";
import {SignatureUtil} from "src/Week20-22/OrderBook/SignatureUtil.sol";

// forge test --mc OrderBookTest -vvvv --via-ir
contract OrderBookTest is Test {
    PermitToken tokenA;
    PermitToken tokenB;
    OrderBook orderBook;
    SignatureUtil signatureUtil;

    uint256 privateKeyUser1;
    address user1;
    uint256 privateKeyUser2;
    address user2;

    function setUp() public {
        tokenA = new PermitToken("TokenA", "A");
        tokenB = new PermitToken("TokenB", "B");
        orderBook = new OrderBook(address(tokenA), address(tokenB));
        signatureUtil = new SignatureUtil();

        privateKeyUser1 = 0x123456789abcdef;
        user1 = vm.addr(privateKeyUser1);

        privateKeyUser2 = 0x987654321fedcba;
        user2 = vm.addr(privateKeyUser2);

        tokenA.transfer(user1, 1000);
        tokenA.transfer(user2, 1000);
        tokenB.transfer(user1, 1000);
        tokenB.transfer(user2, 1000);
    }

    /***************************************************************/
    /*                          Helper Fns                         */
    /***************************************************************/

    function getTokenPermitWithSignature(
        PermitToken _token,
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _nonce,
        uint256 _deadline,
        uint256 _privateKey
    ) internal view returns (PermitWithVRS memory){
        Permit memory permit = Permit({
            owner: _owner,
            spender: _spender,
            value: _value,
            nonce: _nonce,
            deadline: _deadline
        });

        bytes memory permitSignature = signatureUtil.getPermitSignature(
            _token.DOMAIN_SEPARATOR(),
            permit,
            _privateKey
        );

        (bytes32 r, bytes32 s, uint8 v) = signatureUtil.splitSignature(permitSignature);

        return PermitWithVRS({
            tokenAddr: address(_token),
            owner: _owner,
            value: _value,
            deadline: _deadline,
            v: v,
            r: r,
            s: s
        });
    }

    /**********************************************************/
    /*                          Tests                         */
    /**********************************************************/

    /// @dev User1 creates a sell order to sell 100 TokenA for 50 TokenB
    /// and User2 creates a buy order to buy 100 TokenA for 50 TokenB
    function test_executeMatchedOrder() public {
        //User1 approves OrderBook to spend TokenA
        PermitWithVRS memory sellPermit = getTokenPermitWithSignature(
            tokenA,
            user1,
            address(orderBook),
            1000,
            tokenA.nonces(user1),
            block.timestamp + 1000,
            privateKeyUser1
        );

        //User2 approves OrderBook to spend TokenB
        PermitWithVRS memory buyPermit = getTokenPermitWithSignature(
            tokenB,
            user2,
            address(orderBook),
            1000,
            tokenB.nonces(user2),
            block.timestamp + 1000,
            privateKeyUser2
        );

        //User1 creates a sell order to sell 100 TokenA for 50 TokenB
        Order memory sellOrder = Order({
            maker: user1,
            deadline: block.timestamp + 1000,
            sellToken: address(tokenA),
            buyToken: address(tokenB),
            sellTokenAmount: 100,
            buyTokenAmount: 50,
            nonce: orderBook.nonces(user1)
        });
        bytes memory sellOrderSig = signatureUtil.getOrderSignature(
            orderBook.DOMAIN_SEPARATOR(),
            sellOrder,
            privateKeyUser1
        );

        //User2 creates a buy order to buy 100 TokenA for 50 TokenB
        Order memory buyOrder = Order({
            maker: user2,
            deadline: block.timestamp + 1000,
            sellToken: address(tokenB),
            buyToken: address(tokenA),
            sellTokenAmount: 50,
            buyTokenAmount: 100,
            nonce: orderBook.nonces(user2)
        });
        bytes memory buyOrderSig = signatureUtil.getOrderSignature(
            orderBook.DOMAIN_SEPARATOR(),
            buyOrder,
            privateKeyUser2
        );

        orderBook.executeMatchedOrder(
            sellPermit,
            sellOrder,
            sellOrderSig,
            buyPermit,
            buyOrder,
            buyOrderSig
        );

        assertEq(tokenA.balanceOf(address(orderBook)), 0);
        assertEq(tokenB.balanceOf(address(orderBook)), 0);

    }
    
}