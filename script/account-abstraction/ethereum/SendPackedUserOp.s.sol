// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "@aa/contracts/interfaces/PackedUserOperation.sol";

contract SendPackedUserOp is Script {
    function run() public {}

    function generateSignedUserOperation(
        bytes memory callData,
        address sender
    ) public returns (PackedUserOperation memory) {
        uint256 nonce = vm.getNonce(sender);

        PackedUserOperation memory op = _generateSignedUserOperation(callData, sender, nonce);

        return op;
    }

    function _generateSignedUserOperation(
        bytes memory callData,
        address sender,
        uint256 senderNonce
    ) internal pure returns (PackedUserOperation memory) {
        uint128 verificationGasLimit = 16_777_216;
        uint128 callGasLimit = verificationGasLimit; // Often different in practice
        uint128 maxPriorityFeePerGas = 256;
        uint128 maxFeePerGas = maxPriorityFeePerGas; // Simplification for example

        // Pack accountGasLimits: (verificationGasLimit << 128) | callGasLimit
        bytes32 accountGasLimits =
            bytes32((uint256(verificationGasLimit) << 128) | uint256(callGasLimit));

        // Pack gasFees
        bytes32 gasFees = bytes32((uint256(maxFeePerGas) << 128) | uint256(maxPriorityFeePerGas));

        return PackedUserOperation({
            sender: sender,
            nonce: senderNonce,
            initCode: hex"",
            callData: callData,
            accountGasLimits: accountGasLimits,
            preVerificationGas: verificationGasLimit,
            gasFees: gasFees,
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
