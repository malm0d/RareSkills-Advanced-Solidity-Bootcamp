# Why does the SafeERC20 Program Exist?

## USDT or similar non-standard ERC20 tokens
The standard ERC20 token's `transfer` and ` transferFrom` return a boolean value: `true` if the transaction is successful and `false` if the transaction is unsuccessful. More importantly, if the transaction is unsuccessful, it will execute a `revert`. However, non-standard ERC20 tokens, such as USDT, lack this critical feature, and as a result contract calls may fail.
In the case of non-standard ERC20s, they do not return any value from transfer functions, which can lead to unexpected behavior.

## Approve race-condition (Double spending an allowance)
ERC20 has a known race condition through the `approve`/`transferFrom` functions that can lead to attackers stealing funds. In a typical `approve`/`transferFrom` setting, if the token owner decides to change a spender's allowance, they'd have to call `approve` again with the new amount. However, if the spender - who now has malicious intentions, spots the transaction in the mempool before it is finalized, can execute a transaction with higher gas prices to frontrun that transaction. The spender could then transfer the original amount to himself, and then transfer again to himself the new amount that the token owner had just set as allowance.

## SafeERC20 
SafeERC20 was introduced by OZ to address the above challenges. It introduces wrappers around ERC20 functions, such as `safeTransfer` and `safeTransferFrom`, `safeIncreaseAllowance` and `safeDecreaseAllowance`, and accomodates to non-standard ERC20 tokens as well.

### SafeERC20 Transfers
For transfers, the `_callOptionalReturn` internal function will be called:
```
    /**
     * @dev Imitates a Solidity high-level call (i.e. a regular function call to a contract), relaxing the requirement
     * on the return value: the return value is optional (but if data is returned, it must not be false).
     * @param token The token targeted by the call.
     * @param data The call data (encoded using abi.encode or one of its variants).
     */
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        // We need to perform a low level call here, to bypass Solidity's return data size checking mechanism, since
        // we're implementing it ourselves. We use {Address-functionCall} to perform this call, which verifies that
        // the target address contains contract code and also asserts for success in the low-level call.

        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }
```
The `data` argument is the encoded function calldata for the ERC20's `transfer` or `transferFrom` function. And in the function body, the bypass from `Address.functionCall` is needed because ERC20 does not specify specific return types for `transfer`, `transferFrom`, `approve`, and Solidity has a feature which automatically reverts a transaction if the return data size does not match the expected return type. Without the low level call, it will be problematic since standard and non-standard ERC20s are inconsistent in their return values - thus the bypass. The `if` statement then checks the length of the returned data and decodes the returned data. Essentially, if the length is not `0` and the decoded `bool` is `false`, then it will revert.

Note here, that even though USDT and non-standard ERC20s do not return any value from those transfer functions, the `_callOptionalReturn` function checks for the status of the transaction - an error code in the transaction's return data, rather than the return value.

### SafeERC20 Approvals
For approvals, the `forceApprove` internal function will be called:
```
    /**
     * @dev Set the calling contract's allowance toward `spender` to `value`. If `token` returns no value,
     * non-reverting calls are assumed to be successful. Meant to be used with tokens that require the approval
     * to be set to zero before setting it to a non-zero value, such as USDT.
     */
    function forceApprove(IERC20 token, address spender, uint256 value) internal {
        bytes memory approvalCall = abi.encodeCall(token.approve, (spender, value));

        if (!_callOptionalReturnBool(token, approvalCall)) {
            _callOptionalReturn(token, abi.encodeCall(token.approve, (spender, 0)));
            _callOptionalReturn(token, approvalCall);
        }
    }
```
The important thing to note in the `forceApprove` function is that it first reduces the spender's allowance to `0`, and then sets the spender's allowance to the specified amount.

This two-step execution helps to prevent a malicious spender from frontrunning an `approve` transaction as described earlier.

# When Should SafeERC20 be Used?
SafeERC20 should be used as much as possible whenever interacting with ERC20 tokens. Especially when it comes to approving token spending, transferring tokens, and any form of interaction with non-standard ERC20 tokens like USDT.