#### Question 1: The OZ upgrade tool for hardhat defends against 6 kinds of mistakes. What are they and why do they matter?
#### Answer: 
1. `/// @custom:oz-upgrades-unsafe-allow constructor`: Prevents the implementation contract from being used after it is initialized. Although the implementation contract will have no influence on the proxy's storage, it could still be used directly without the proxy. Should invoke `_disableInitializers` in the constructor to automatically lock the implemenation contract when it is deployed.

2. `/// @custom:oz-upgrades-unsafe-allow state-variable-immutable`: Upgradeable contracts have no constructors but initializers, and immutable variables are only assigned in the constructor, so they can't handle immutable variables.

3. `/// @custom:oz-upgrades-unsafe-allow selfdestruct`: If the direct call to the logic contract triggers a selfdestruct operation, then the logic contract will be destroyed, and all your contract instances will end up delegating all calls to an address without any code. If the logic contract contains a delegatecall operation, and it is made to delegatecall into a malicious contract that contains a selfdestruct, then the calling contract will be destroyed (since the context of the delegatecall execution is the logic contract).

4. `/// @custom:oz-upgrades-unsafe-allow delegatecall`: The risk comes with the fact that `delegatecall` can be used to call any arbitrary function in any specified contract, which may include a `selfdestruct` operation. The execution context of the `delegatecall` would be the implementaion contract if it executes if the low-level operation is invoked, putting the implementation at risk (see reasoning in above point).

5. `/// @custom:oz-upgrades-unsafe-allow external-library-linking`: It is not known at compile time what implementation is going to be linked to the proxy, which makes it difficult to guarantee the safety of the upgrade operation. Thus external libraries cant be used with upgradeable contracts.


6. `/// @custom:oz-upgrades-unsafe-allow state-variable-assignment`: State variables cannot be assigned at the top-level scope (nor in the constructor) in upgradeable contracts or between upgrades. The bytecode of the proxy does not include the constructor logic of the implementation contract, so any assignment of state variables will not be executed. All initial state values should be set in an `initialize` function instead. This prevents state variables from being initialized incorrectly between upgrades. However, it is ok to do so with `constant` state variables since these variables are embedded in the bytecode of the implemenation.


&nbsp;
#### Question 2: What is a beacon proxy used for?
#### Answer:
A beacon proxy is (can be) used when we want multiple proxies, that are using the same implementation, to be upgraded in a single transaction. A beacon proxy retrieves the implementation from a beacon contract which holds the implementation address, and upgrade operations are sent to the beacon contract instead of the proxy.

&nbsp;
#### Question 3: Why does the openzeppelin upgradeable tool insert something like `uint256[50] private __gap;` inside the contracts? To see it, create an upgradeable smart contract that has a parent contract and look in the parent.
#### Answer:
This is in reference to storage gaps. Storage gaps are used to reserve storage slots in the storage layout of a contract, allowing future versions of the contract to use up reserved storage slots without affecting the storage layout of an inheriting contracts. Storage gaps are needed for base contracts if they are intended to be upgradeable, as they would allow the base contract to introduce new storage variables without affecting the storage layout of the inheriting contract(s) since storage slots in the base contract have already been reserved. Without the gap, any new storage variables introduced to the base contract would affect the inheriting contract's storage layout, 

&nbsp;
#### Question 4: What is the difference between initializing the proxy and initializing the implementation? Do you need to do both? When do they need to be done?
#### Answer:
The proxy (upgradeable proxy) is initialized during its deployment with an initial implementation contract address specified in its constructor. The implementation contract is only initialized when it is linked to the proxy through an `initialize` function which replaces the constructor (since the implementation's constructor will never be executed in the context of the proxy). When initializing the implementation, it must only be done once during its lifetime and safeguarded to prevent it from being initialized more than once (so in a way it behave like a regular `constructor` which is only called once during deployment). Both need to be done and the initialization should be done as soon as possible, especially the implementation contract - to prevent it from being taken over by an attacker, but in general dont leave an implementation contract uninitialized.

&nbsp;
#### Question 5: What is the use for the reinitializer? Provide a minimal example of proper use in Solidity
#### Answer:
After the original initialization step, if we want to upgrade and add new storage slots &/or new modules and they need to be initialized, we may use `reinitializer` modifier to initialize these new storage slots &/or modules. Importantly, When version is 1, this modifier is similar to `initializer``, except that functions marked with reinitializer cannot be nested. If one is invoked in the context of another, execution will revert.

Very minimal example:
```
contract SomeUpgradeableERC20 is Initializable, ERC20Upgradeable, OwnableUpgradeable, UUPSUpgradeable {
    function initialize(string memory name, string memory symbol) public initializer {
        __ERC20_init(name, symbol);
        __Ownable_init();
        __UUPSUpgradeable_init();
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    // Example reinitializer function for version 2
    // Assume we want to add a new state variable in the upgrade.
    // Assume we want to inherit a new base contract in the inheritance chain
    // for additional functionalities.

    uint256 public newVariable;

    function reinitializeAsV2(uint256 _newVariable) public onlyOwner reinitializer(2) {
        newVariable = _newVariable;
        __initSomeOtherNewlyInheritedBaseContract();
    }
}
```