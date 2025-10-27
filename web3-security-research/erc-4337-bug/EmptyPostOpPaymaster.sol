// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "../lib/account-abstraction/contracts/core/BasePaymaster.sol";
import "../lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import "../lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import "../lib/account-abstraction/contracts/interfaces/IPaymaster.sol";

contract EmptyPostOpPaymaster is BasePaymaster {
    constructor(IEntryPoint _entryPoint) BasePaymaster(_entryPoint) {}

    function _validatePaymasterUserOp(
        PackedUserOperation calldata userOp,
        bytes32 /*userOpHash*/,
        uint256 /*maxCost*/
    ) internal pure override returns (bytes memory context, uint256 validationData) {
        // Minimal validation, just return empty context and success
        return (abi.encode(bytes("")), 0);
    }

    function _postOp(
        IPaymaster.PostOpMode /*mode*/,
        bytes calldata /*context*/,
        uint256 /*actualGasCost*/,
        uint256 /*actualUserOpFeePerGas*/
    ) internal pure override {
        // This postOp is intentionally empty and does nothing.
        // It should consume minimal gas.
    }
}
