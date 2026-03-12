// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {EntryPoint} from "@aa/contracts/core/EntryPoint.sol";

struct NetworkConfig {
    address entryPoint;
    address account; // Deployer/burner wallet address
}

contract HelperConfig is Script {
    // Chain ID Constants
    uint256 constant ETH_SEPOLIA_CID = 11_155_111;
    uint256 constant ZKSYNC_SEPOLIA_CID = 300;
    uint256 constant LOCAL_CID = 31_337; // Anvil default

    // First acct
    address constant BURNER_WALLET = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
    address constant ANVIL_DEFAULT_ACCOUNT = 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;

    // State Variable
    NetworkConfig public localNetworkConfig;
    mapping(uint256 cid => NetworkConfig) public networkConfigs;

    //errors
    error HelperConfig__InvalidChainId();

    constructor() {
        networkConfigs[ETH_SEPOLIA_CID] = getEthSepoliaConfig();
        networkConfigs[ZKSYNC_SEPOLIA_CID] = getZkSyncSepoliaConfig();
    }

    function getEthSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({
            entryPoint: 0x5FF137D4b0FDCD49DcA30c7CF57E578a026d2789, account: BURNER_WALLET
        });
    }

    function getZkSyncSepoliaConfig() public pure returns (NetworkConfig memory) {
        return NetworkConfig({entryPoint: address(0), account: BURNER_WALLET});
    }

    function getOrCreateLocalEthConfig() public returns (NetworkConfig memory) {
        if (localNetworkConfig.account != address(0)) {
            return localNetworkConfig;
        }

        console.log("Deploying mocks for Anvil...");
        vm.startBroadcast(ANVIL_DEFAULT_ACCOUNT);
        EntryPoint entryPoint = new EntryPoint();
        vm.stopBroadcast();

        localNetworkConfig =
            NetworkConfig({entryPoint: address(entryPoint), account: ANVIL_DEFAULT_ACCOUNT});

        return localNetworkConfig;
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetworkConfig memory) {
        if (chainId == LOCAL_CID) {
            return getOrCreateLocalEthConfig();
        }
        if (networkConfigs[chainId].account != address(0)) {
            // Check if config exists
            return networkConfigs[chainId];
        }
        revert HelperConfig__InvalidChainId();
    }

    function getConfig() public returns (NetworkConfig memory) {
        return getConfigByChainId(block.chainid);
    }
}
