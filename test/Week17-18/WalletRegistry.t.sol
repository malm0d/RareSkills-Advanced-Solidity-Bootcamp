// SPDX-License-Identifier: MIT
pragma solidity 0.8.21;

import "forge-std/Test.sol";
import {Utilities} from "./Utilities.sol";

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
/// 1. 