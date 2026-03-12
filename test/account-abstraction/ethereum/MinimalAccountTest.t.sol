// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {MinimalAccount} from "src/account-abstraction/ethereum/MinimalAccount.sol";
import {DeployMinimal} from "script/account-abstraction/ethereum/DeployMinimal.s.sol";
import {HelperConfig} from "script/account-abstraction/ethereum/HelperConfig.s.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract MinimalAccountTest is Test {
    HelperConfig helperConfig;
    MinimalAccount minimalAccount;
    ERC20Mock usdc;
    uint256 constant AMOUNT = 1e18;
    address randomUser = makeAddr("randomUser");

    function setUp() public {
        DeployMinimal deployMinimal = new DeployMinimal();
        (helperConfig, minimalAccount) = deployMinimal.deployMinimalAccount();
        vm.label(address(minimalAccount), "SCW");

        usdc = new ERC20Mock();
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
}
