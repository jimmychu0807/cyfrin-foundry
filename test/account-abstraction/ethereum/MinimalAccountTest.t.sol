// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";

import {MinimalAccount} from "src/account-abstraction/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/account-abstraction/ethereum/DeployMinimal.s.sol";
import {HelperConfig, NetworkConfig} from "script/account-abstraction/ethereum/HelperConfig.s.sol";
import {
    SendPackedUserOp,
    PackedUserOperation
} from "script/account-abstraction/ethereum/SendPackedUserOp.s.sol";

import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {IEntryPoint} from "@aa/contracts/interfaces/IEntryPoint.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";

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
        vm.label(address(minimalAccount), "SCW");

        usdc = new ERC20Mock();

        sendPackedUserOpScript = new SendPackedUserOp();
        helperConfig = new HelperConfig();
        networkConfig = helperConfig.getOrCreateLocalEthConfig();
        sendPackedUserOpScript.setUp(helperConfig);
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

    function testRecoverSignedOp() public {
        // Arrange
        uint256 AMOUNT = 100e6;
        bytes memory functionDataForUSDCMint =
            abi.encodeCall(ERC20Mock.mint, (address(minimalAccount), AMOUNT));

        bytes memory executeCallData =
            abi.encodeCall(minimalAccount.execute, (address(usdc), 0, functionDataForUSDCMint));

        // Generate the signedPackedUserOperation
        PackedUserOperation memory packedUserOp =
            sendPackedUserOpScript.generateSignedUserOperation(executeCallData, networkConfig);

        // Get the userOpHash
        bytes32 userOperationHash =
            IEntryPoint(networkConfig.entryPoint).getUserOpHash(packedUserOp);

        // Act
        address actualSigner =
            ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOp.signature);

        // Assert
        assertEq(actualSigner, minimalAccount.owner(), "Signer recovery failed");
    }
}
