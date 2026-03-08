// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {BoxV1, BoxV2} from "../../src/upgradeable-contract/Box.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {DevOpsTools} from "@cyfrin/foundry-devops/DevOpsTools.sol";

contract DeployBox is Script {
    function run() external returns (address) {
        address proxy = deployBox();
        return proxy;
    }

    function deployBox() internal returns (address) {
        vm.startBroadcast();
        BoxV1 box = new BoxV1(); // impl
        ERC1967Proxy proxy = new ERC1967Proxy(address(box), abi.encodeCall(BoxV1.initialize, ()));
        vm.stopBroadcast();

        return address(proxy);
    }
}

contract UpgradeBox is Script {
    function run() external returns (address) {
        address recentDeployment =
            DevOpsTools.get_most_recent_deployment("ERC1967Proxy", block.chainid);

        vm.startBroadcast();
        BoxV2 newBox = new BoxV2();
        address proxy = upgradeBox(recentDeployment, address(newBox));
        vm.stopBroadcast();

        return proxy;
    }

    function upgradeBox(
        address proxyAddress,
        address newBox
    ) public returns (address) {
        vm.startBroadcast();
        BoxV1 proxy = BoxV1(proxyAddress);
        proxy.upgradeToAndCall(address(newBox), "");
        vm.stopBroadcast();

        return address(proxy);
    }
}
