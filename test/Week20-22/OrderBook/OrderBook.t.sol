//SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console, console2} from "forge-std/Test.sol";
import {PermitToken} from "src/Week20-22/OrderBook/PermitToken.sol";
import {OrderBook, Order, Permit} from "src/Week20-22/OrderBook/OrderBook.sol";
import {SignatureUtil} from "src/Week20-22/OrderBook/SignatureUtil.sol";

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
    }
    
}