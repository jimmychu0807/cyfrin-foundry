// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {
    PackedUserOperation
} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {
    SIG_VALIDATION_FAILED,
    SIG_VALIDATION_SUCCESS
} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

// The flow for ERC-4337 typically involves an EntryPoint contract
// calling into this account contract.
contract MinimalAccount is IAccount, Ownable {
    /////////////////
    // Constant / Immutable
    /////////////////

    IEntryPoint private immutable i_entryPoint;

    /////////////////
    // Storage
    /////////////////

    /////////////////
    // Event
    /////////////////

    /////////////////
    // Error
    /////////////////

    error MinimalAccount__NotFromEntryPoint();
    error MinimalAccount__NotFromEntryPointOrOwner();
    error MinimalAccount__CallFailed(bytes result);

    /////////////////
    // Modifier
    /////////////////

    modifier requireFromEntryPoint() {
        require(msg.sender == address(i_entryPoint), MinimalAccount__NotFromEntryPoint());
        _;
    }

    modifier requireFromEntryPointOrOwner() {
        require(
            msg.sender == address(i_entryPoint) || msg.sender == owner(),
            MinimalAccount__NotFromEntryPointOrOwner()
        );
        _;
    }

    // Constructor
    constructor(
        address entryPoint,
        address initialOwner
    ) Ownable(initialOwner) {
        i_entryPoint = IEntryPoint(entryPoint);
    }

    // receive(), fallback() - allow receiving ethers
    receive() external payable {}

    /////////////////
    // Public / External functions
    /////////////////

    function validateUserOp(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash,
        uint256 missingAccountFunds
    ) external view override requireFromEntryPoint returns (uint256 validationData) {
        // TODO: implement additional validation logic (signature, nonce)
        validationData = _validateSignature(userOp, userOpHash);
    }

    function execute(
        address dest,
        uint256 value,
        bytes calldata functionData
    ) external requireFromEntryPointOrOwner {
        (bool success, bytes memory result) = dest.call{value: value}(functionData);
        require(success, MinimalAccount__CallFailed(result));
    }

    /////////////////
    // Private / Internal functions
    /////////////////

    function _validateSignature(
        PackedUserOperation calldata userOp,
        bytes32 userOpHash
    ) internal view returns (uint256 validationData) {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);

        if (signer == address(0) || signer != owner()) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    /////////////////
    // Viewers / Getters
    /////////////////
    function getEntryPoint() external view returns (address) {
        return address(i_entryPoint);
    }
}
