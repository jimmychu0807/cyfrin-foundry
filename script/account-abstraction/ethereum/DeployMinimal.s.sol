// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {MinimalAccount} from "src/account-abstraction/ethereum/MinimalAccount.sol"; // Adjust path as needed
import {HelperConfig, NetworkConfig} from "./HelperConfig.s.sol"; // Relative path to HelperConfig

contract DeployMinimal is Script {
    function deployMinimalAccount()
        public
        returns (HelperConfig helperConfigInstance, MinimalAccount minimalAccountContract)
    {
        HelperConfig helperConfig = new HelperConfig();

        NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account); // Use the burner wallet from config for broadcasting

        MinimalAccount minimalAccount = new MinimalAccount(config.entryPoint, config.account);

        vm.stopBroadcast();

        return (helperConfig, minimalAccount);
    }

    function run() public returns (HelperConfig, MinimalAccount) {
        return deployMinimalAccount();
    }
}
