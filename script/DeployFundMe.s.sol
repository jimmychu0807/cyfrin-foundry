//SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {FundMe} from "../src/FundMe.sol";
import {DeployFundMeHelperConfig} from "./DeployFundMeHelperConfig.s.sol";

contract DeployFundMeScript is Script {
    function run() external returns (FundMe) {
        DeployFundMeHelperConfig helperConfig = new DeployFundMeHelperConfig();
        address priceFeed = helperConfig.activeNetworkConfig();

        vm.startBroadcast();
        FundMe fundMe = new FundMe(priceFeed);
        vm.stopBroadcast();

        return fundMe;
    }
}
