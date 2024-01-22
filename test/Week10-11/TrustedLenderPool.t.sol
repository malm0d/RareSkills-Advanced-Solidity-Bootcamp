// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test, console2} from "forge-std/Test.sol";
import {TrusterLenderPool, DamnValuableToken, Exploit} from "../../src/Week10-11/TrusterLenderPool.sol";

// forge test --match-contract TrusterLenderPoolTest -vvvv
contract TrusterLenderPoolTest is Test {
    TrusterLenderPool pool;
    DamnValuableToken token;
    Exploit exploitContract;
    address deployer;
    address player;

    function setUp() public {
        token = new DamnValuableToken();
        pool = new TrusterLenderPool(token);
        assertEq(address(pool.token()), address(token));

        token.transfer(address(pool), 1_000_000 * 10 ** 18);
        assertEq(token.balanceOf(address(pool)), 1_000_000 * 10 ** 18);
        assertEq(token.balanceOf(player), 0);

        exploitContract = new Exploit(pool, token);
    }

    function testExploit() public {
        vm.startPrank(player);
        exploitContract.exploit();
        _checkSolved();
    }

    function _checkSolved() internal {
        assertEq(token.balanceOf(player), 1_000_000 * 10 ** 18);
        assertEq(token.balanceOf(address(pool)), 0);
    }
}
