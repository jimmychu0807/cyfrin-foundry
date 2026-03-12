// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";

import {MinimalAccount} from "src/account-abstraction/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/account-abstraction/ethereum/DeployMinimal.s.sol";
import {HelperConfig, NetworkConfig} from "script/account-abstraction/ethereum/HelperConfig.s.sol";
import {
    SendPackedUserOp,
    PackedUserOperation
} from "script/account-abstraction/ethereum/SendPackedUserOp.s.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IEntryPoint} from "@aa/contracts/interfaces/IEntryPoint.sol";
import {SIG_VALIDATION_FAILED, SIG_VALIDATION_SUCCESS} from "@aa/contracts/core/Helpers.sol";

using MessageHashUtils for bytes32;

contract MinimalAccountTest is Test {
    uint256 constant AMOUNT = 1e18;

    address randomUser = makeAddr("randomUser");
    SendPackedUserOp sendPackedUserOpScript;
    HelperConfig helperConfig;
    NetworkConfig networkConfig;
    MinimalAccount minimalAccount;
    IEntryPoint mockEntryPoint;

    address owner;
    ERC20Mock usdc;

    function setUp() public {
        DeployMinimal deployMinimal = new DeployMinimal();
        (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
        networkConfig = helperConfig.getConfig();

        usdc = new ERC20Mock();

        sendPackedUserOpScript = new SendPackedUserOp();
        sendPackedUserOpScript.setUp(helperConfig);

        vm.label(address(minimalAccount), "SCW");
        vm.label(address(networkConfig.account), "SCW_OWNER");
        vm.label(address(networkConfig.entryPoint), "ENTRYPOINT");
    }

    function testOwnerCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0, "initial USDC balance should be 0");
        address dest = address(usdc);
        uint256 value = 0;

        // Arrange: Prepare calldata
        bytes memory functionData =
            abi.encodeCall(ERC20Mock.mint, (address(minimalAccount), AMOUNT));

        // Act
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(dest, value, functionData);

        // Assert
        assertEq(
            usdc.balanceOf(address(minimalAccount)),
            AMOUNT,
            "minimalAccount should have minted USDC"
        );
    }

    function testNonOwnerCannotExecuteCommands() public {
        // Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData =
            abi.encodeCall(ERC20Mock.mint, (address(minimalAccount), AMOUNT));

        // Act
        vm.prank(randomUser);
        vm.expectRevert(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector);
        minimalAccount.execute(dest, value, functionData);
    }

    function testRecoverSignedOp() public view {
        // Arrange
        uint256 usdcAmt = 100e6;
        bytes memory functionDataForUSDCMint =
            abi.encodeCall(ERC20Mock.mint, (address(minimalAccount), usdcAmt));

        bytes memory executeCallData =
            abi.encodeCall(minimalAccount.execute, (address(usdc), 0, functionDataForUSDCMint));

        // Generate the signedPackedUserOperation
        PackedUserOperation memory packedUserOp = sendPackedUserOpScript.generateSignedUserOperation(
            executeCallData, networkConfig, address(minimalAccount)
        );

        // Get the userOpHash
        bytes32 userOperationHash =
            IEntryPoint(networkConfig.entryPoint).getUserOpHash(packedUserOp);

        // Act
        address actualSigner =
            ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);

        // Assert
        assertEq(actualSigner, minimalAccount.owner(), "Signer recovery failed");
    }

    function testValidationOfUserOps() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        uint256 usdcAmt = 100e6;

        bytes memory functionData =
            abi.encodeCall(ERC20Mock.mint, (address(minimalAccount), usdcAmt));

        bytes memory executeCallData =
            abi.encodeCall(minimalAccount.execute, (address(usdc), 0, functionData));

        // Generate the signedPackedUserOperation
        PackedUserOperation memory packedUserOp = sendPackedUserOpScript.generateSignedUserOperation(
            executeCallData, networkConfig, address(minimalAccount)
        );

        // Get the userOpHash
        bytes32 userOperationHash =
            IEntryPoint(networkConfig.entryPoint).getUserOpHash(packedUserOp);

        uint256 missingAccountFunds = 1e18;

        // Act
        vm.prank(address(networkConfig.entryPoint));
        uint256 validationData =
            minimalAccount.validateUserOp(packedUserOp, userOperationHash, missingAccountFunds);

        assertEq(validationData, SIG_VALIDATION_SUCCESS);
    }

    function testEntryPointCanExecuteCommands() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        uint256 usdcAmt = 100e6;

        bytes memory functionData =
            abi.encodeCall(ERC20Mock.mint, (address(minimalAccount), usdcAmt));

        bytes memory executeCallData =
            abi.encodeCall(minimalAccount.execute, (address(usdc), 0, functionData));

        // Generate the signedPackedUserOperation
        PackedUserOperation memory packedUserOp = sendPackedUserOpScript.generateSignedUserOperation(
            executeCallData, networkConfig, address(minimalAccount)
        );

        // Deposit to the entrypoint stake manager
        vm.deal(address(minimalAccount), 10e18);
        vm.prank(address(minimalAccount));
        (bool success,) = networkConfig.entryPoint.call{value: 1e17}("");
        require(success, "transfer failed");

        // Act
        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOp;

        vm.prank(randomUser);
        IEntryPoint(networkConfig.entryPoint).handleOps(ops, payable(randomUser));

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), usdcAmt);
    }
}
