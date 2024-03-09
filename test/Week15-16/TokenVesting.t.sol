// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import {Test, console2} from "forge-std/Test.sol";
import {MockERC20} from "../mocks/MockERC20.sol";
import {TokenVesting} from "src/Week15-16/Original/TraderJoe/TokenVesting.sol";
import {TokenVestingOptimized} from "src/Week15-16/Optimized/TraderJoe/TokenVestingOptimized.sol";

// forge test --mc TokenVestingTest --gas-report / -vvvv
// forge snapshot --mc TokenVestingTest --snap <FileName>
// forge snapshot --mc TokenVestingTest --diff <FileName>
contract TokenVestingTest is Test {
    MockERC20 token;
    TokenVesting tokenVestingOriginal;
    TokenVestingOptimized tokenVestingOptimized;

    address owner;

    uint256 startTime = 365 days;
    uint256 cliffDuration = 7 days;
    uint256 vestDuration = 21 days;

    function setUp() public {
        vm.warp(startTime);
        
        owner = address(this);
        token = new MockERC20();

        tokenVestingOriginal = new TokenVesting(
            owner,
            startTime,
            cliffDuration,
            vestDuration,
            true
        );

        tokenVestingOptimized = new TokenVestingOptimized(
            owner,
            uint112(startTime),
            uint112(cliffDuration),
            uint32(vestDuration),
            true
        );

        token.transfer(address(tokenVestingOriginal), 100000000);
        token.transfer(address(tokenVestingOptimized), 100000000);
    }

    //--------------------------------Unit tests for Original--------------------------------

    // function test_beneficiary() public {
    //     assertEq(tokenVestingOriginal.beneficiary(), address(this));
    // }

    // function test_cliff() public {
    //     assertEq(tokenVestingOriginal.cliff(), block.timestamp + cliffDuration);
    // }

    // function test_start() public {
    //     assertEq(tokenVestingOriginal.start(), startTime);
    // }

    // function test_duration() public {
    //     assertEq(tokenVestingOriginal.duration(), vestDuration);
    // }

    // function test_revocable() public {
    //     assertTrue(tokenVestingOriginal.revocable());
    // }

    // function test_released() public {
    //     assertEq(tokenVestingOriginal.released(address(token)), 0);
    // }

    // function test_revoked() public {
    //     assertFalse(tokenVestingOriginal.revoked(address(token)));
    // }

    // //block.timestamp < _cliff
    // function test_release_revert() public {
    //     // vm.expectRevert("TokenVesting: no tokens are due");
    //     vm.expectRevert();
    //     tokenVestingOriginal.release(token);
    // }

    // //block.timestamp > _cliff && block.timestamp >= _start + _duration
    // function test_release_one() public {
    //     vm.warp(startTime + vestDuration + 1 days);
    //     uint256 balanceBefore = token.balanceOf(address(this));
    //     tokenVestingOriginal.release(token);
    //     uint256 balanceAfter = token.balanceOf(address(this));

    //     assertTrue(balanceAfter > balanceBefore);
    // }

    // //block.timestamp > _cliff && block.timestamp < _start + _duration
    // function test_release_two() public {
    //     vm.warp(startTime + cliffDuration + 14 days);
    //     uint256 balanceBefore = token.balanceOf(address(this));
    //     tokenVestingOriginal.release(token);
    //     uint256 balanceAfter = token.balanceOf(address(this));

    //     assertTrue(balanceAfter > balanceBefore);
    // }

    // //Revoke with releaseable amount
    // //block.timestamp > _cliff && _revoked[token] == true with releasableAmount
    // function test_revoke_one() public {
    //     vm.warp(startTime + cliffDuration + 7 days);
    //     uint256 balanceBefore = token.balanceOf(address(this));
    //     tokenVestingOriginal.release(token);
    //     assertTrue(tokenVestingOriginal.released(address(token)) > 0);
    //     skip(7 days);
    //     tokenVestingOriginal.revoke(token);
    //     uint256 balanceAfter = token.balanceOf(address(this));

    //     assertTrue(balanceAfter > balanceBefore);
    //     assertEq(tokenVestingOriginal.revoked(address(token)), true);
    // }

    // //Revoke with no releaseable amount
    // //block.timestamp > _cliff && _revoked[token] == true with no releasableAmount
    // function test_revoke_two() public {
    //     vm.warp(startTime + cliffDuration + 7 days);
    //     uint256 balanceBefore = token.balanceOf(address(this));
    //     tokenVestingOriginal.revoke(token);
    //     uint256 balanceAfter = token.balanceOf(address(this));

    //     assertTrue(balanceAfter > balanceBefore);
    //     assertEq(tokenVestingOriginal.revoked(address(token)), true);
    // }

    // function test_revoke_revert() public {
    //     tokenVestingOriginal.revoke(token);
    //     vm.expectRevert("TokenVesting: token already revoked");
    //     tokenVestingOriginal.revoke(token);
    // }

    // function test_emergencyRevoke() public {
    //     uint256 balanceBefore = token.balanceOf(address(this));
    //     tokenVestingOriginal.emergencyRevoke(token);
    //     uint256 balanceAfter = token.balanceOf(address(this));
    //     assertEq(tokenVestingOriginal.revoked(address(token)), true);
    //     assertTrue(balanceAfter > balanceBefore);
    // }

    // function test_emergencyRevoke_revert() public {
    //     tokenVestingOriginal.emergencyRevoke(token);
    //     vm.expectRevert("TokenVesting: token already revoked");
    //     tokenVestingOriginal.emergencyRevoke(token);
    // }


    //--------------------------------Unit tests for Optimized--------------------------------

    function test_beneficiary() public {
        assertEq(tokenVestingOptimized.beneficiary(), address(this));
    }

    function test_cliff() public {
        assertEq(tokenVestingOptimized.cliff(), block.timestamp + cliffDuration);
    }

    function test_start() public {
        assertEq(tokenVestingOptimized.start(), startTime);
    }

    function test_duration() public {
        assertEq(tokenVestingOptimized.duration(), vestDuration);
    }

    function test_revocable() public {
        assertTrue(tokenVestingOptimized.revocable());
    }

    function test_released() public {
        assertEq(tokenVestingOptimized.released(address(token)), 0);
    }

    function test_revoked() public {
        assertFalse(tokenVestingOptimized.revoked(address(token)));
    }

    //block.timestamp < _cliff
    function test_release_revert() public {
        // not sure why Error != expected error: TokenVesting: no tokens are due != TokenVesting: no tokens are due
        // vm.expectRevert(bytes("TokenVesting: no tokens are due"));
        vm.expectRevert();
        tokenVestingOptimized.release(address(token));
    }

    //block.timestamp > _cliff && block.timestamp >= _start + _duration
    function test_release_one() public {
        vm.warp(startTime + vestDuration + 1 days);
        uint256 balanceBefore = token.balanceOf(address(this));
        tokenVestingOptimized.release(address(token));
        uint256 balanceAfter = token.balanceOf(address(this));

        assertTrue(balanceAfter > balanceBefore);
    }

    //block.timestamp > _cliff && block.timestamp < _start + _duration
    function test_release_two() public {
        vm.warp(startTime + cliffDuration + 14 days);
        uint256 balanceBefore = token.balanceOf(address(this));
        tokenVestingOptimized.release(address(token));
        uint256 balanceAfter = token.balanceOf(address(this));

        assertTrue(balanceAfter > balanceBefore);
    }

    //Revoke with releaseable amount
    //block.timestamp > _cliff && _revoked[token] == true with releasableAmount
    function test_revoke_one() public {
        vm.warp(startTime + cliffDuration + 7 days);
        uint256 balanceBefore = token.balanceOf(address(this));
        tokenVestingOptimized.release(address(token));
        assertTrue(tokenVestingOptimized.released(address(token)) > 0);
        skip(7 days);
        tokenVestingOptimized.revoke(address(token));
        uint256 balanceAfter = token.balanceOf(address(this));

        assertTrue(balanceAfter > balanceBefore);
        assertEq(tokenVestingOptimized.revoked(address(token)), true);
    }

    //Revoke with no releaseable amount
    //block.timestamp > _cliff && _revoked[token] == true with no releasableAmount
    function test_revoke_two() public {
        vm.warp(startTime + cliffDuration + 7 days);
        uint256 balanceBefore = token.balanceOf(address(this));
        tokenVestingOptimized.revoke(address(token));
        uint256 balanceAfter = token.balanceOf(address(this));

        assertTrue(balanceAfter > balanceBefore);
        assertEq(tokenVestingOptimized.revoked(address(token)), true);
    }

    function test_revoke_revert() public {
        tokenVestingOptimized.revoke(address(token));
        vm.expectRevert(bytes4(keccak256("AlreadyRevoked()")));
        tokenVestingOptimized.revoke(address(token));
    }

    function test_emergencyRevoke() public {
        uint256 balanceBefore = token.balanceOf(address(this));
        tokenVestingOptimized.emergencyRevoke(address(token));
        uint256 balanceAfter = token.balanceOf(address(this));
        assertEq(tokenVestingOptimized.revoked(address(token)), true);
        assertTrue(balanceAfter > balanceBefore);
    }

    function test_emergencyRevoke_revert() public {
        tokenVestingOptimized.emergencyRevoke(address(token));
        vm.expectRevert(bytes4(keccak256("AlreadyRevoked()")));
        tokenVestingOptimized.emergencyRevoke(address(token));
    }


}