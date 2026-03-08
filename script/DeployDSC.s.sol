// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DeployDSCHelperConfig} from "./DeployDSCHelperConfig.s.sol";

contract DeployDSC is Script {
    address[] private tokenAddresses;
    address[] private priceFeeds;

    function run() external returns (DecentralizedStableCoin, DSCEngine, DeployDSCHelperConfig) {
        DeployDSCHelperConfig config = new DeployDSCHelperConfig();
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc,) =
            config.activeNetworkConfig();
        tokenAddresses = [weth, wbtc];
        priceFeeds = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        vm.startBroadcast(msg.sender);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin(msg.sender);
        DSCEngine engine = new DSCEngine(tokenAddresses, priceFeeds, address(dsc));
        dsc.transferOwnership(address(engine));
        vm.stopBroadcast();

        return (dsc, engine, config);
    }
}

