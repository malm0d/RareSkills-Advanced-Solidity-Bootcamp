### 1. When a contract calls another call via call, delegatecall, or staticcall, how is information passed between them? Where is this data stored?
They are all passed in calldata in all cases.

### 2. If a proxy calls an implementation, and the implementation self-destructs in the function that gets called, what happens?
The proxy gets destroyed because the execution context is the proxy.

### 3. If a proxy calls an empty address or an implementation that was previously self-destructed, what happens?
The call will succeed. In an empty address or an implementation that was previously self-destructed, the code and storage is cleared but the address still exists. Thus when a delegatecall calls such an address, it is considered successful.

### 4. If a user calls a proxy makes a delegatecall to A, and A makes a regular call to B, from A's perspective, who is msg.sender? from B's perspective, who is msg.sender? From the proxy's perspective, who is msg.sender?
The flow is: EOA -> proxy --delegatecall--> A --call--> B. From A's perspective, msg.sender is the EOA. From B's perspective, msg.sender is the proxy (The execution context of the delegatecall is the proxy, and A is only the logic, so when the proxy delegates a call to A, and A makes a regular call to B, the context is the proxy so msg.sender from B's perspective is the proxy). From the proxy's perspective, msg.sender is the EOA.

### 5. If a proxy makes a delegatecall to A, and A does address(this).balance, whose balance is returned, the proxy's or A?
The proxy because when the delegatecall was made the execution context is the proxy.


### 6. If a proxy makes a delegatecall to A, and A calls codesize, is codesize the size of the proxy or A?
It returns the size of the called contract: A, not the proxy's size. Codesize will get the code size of the current contract.

### 7. If a delegatecall is made to a function that reverts, what does the delegatecall do?
If we do not check such as: `(bool success, bytes memory data) = _contract.delegatecall(...)`, it will not revert - it will silently fail.

### 8. Under what conditions does the Openzeppelin Proxy.sol overwrite the free memory pointer? Why is it safe to do this?
When `_delegate` is called in the `fallback` function, after a `delegatecall`, `returndatacopy(0, 0, returndatasize())` is called and this potentially overwrites the free memory pointer if the return data size is large enough. It is safe to do this because no additional solidity code is executed after, and the memory is only used for the delegatecall workflow.

### 9. If a delegatecall is made to a function that reads from an immutable variable, what will the value be?
Immutable variables are stored directly in the bytecode of the contract, not the storage. So when a delegatecall is made to a function in the implementation contract that reads from an immutable variable, the value returned will be the value in the context of the implementation contract that contains the code (and value). It reads from the implementation contract where the function resides.

### 10. If a delegatecall is made to a contract that makes a delegatecall to another contract, who is msg.sender in the proxy, the first contract, and the second contract?
The flow is: EOA -> proxy --delegatecall--> first contract --delegatecall--> second contract. From the proxy's perspective, msg.sender is the EOA. From the first contract's perspective, msg.sender is the EOA. From the second contract's perspective, msg.sender is the EOA.