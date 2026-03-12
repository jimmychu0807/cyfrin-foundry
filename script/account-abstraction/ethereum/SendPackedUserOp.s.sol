// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {PackedUserOperation} from "@aa/contracts/interfaces/PackedUserOperation.sol";
import {HelperConfig, NetworkConfig} from "script/account-abstraction/ethereum/HelperConfig.s.sol";
import {IEntryPoint} from "@aa/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

using MessageHashUtils for bytes32;

uint256 constant ANVIL_DEFAULT_PRIVATE_KEY =
    0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

contract SendPackedUserOp is Script {
    HelperConfig public helperConfig;

    function setUp(
        HelperConfig _helperConfig
    ) public {
        helperConfig = _helperConfig;
    }

    function run() public {}

    function generateSignedUserOperation(
        bytes memory callData,
        NetworkConfig memory config,
        address minimalAccount
    ) public view returns (PackedUserOperation memory) {
        uint256 nonce = IEntryPoint(config.entryPoint).getNonce(minimalAccount, 0);

        PackedUserOperation memory op =
            _generateSignedUserOperation(callData, minimalAccount, nonce);

        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(op);

        bytes32 digest = userOpHash.toEthSignedMessageHash();

        uint8 v;
        bytes32 r;
        bytes32 s;
        if (block.chainid == 31_337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_PRIVATE_KEY, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest);
        }

        op.signature = abi.encodePacked(r, s, v);

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
