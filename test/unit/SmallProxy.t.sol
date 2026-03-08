// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {
    SmallProxy,
    ImplementationA,
    ImplementationB
} from "../../src/upgradeable-contract/SmallProxy.sol";

contract SmallProxyTest is Test {
    SmallProxy proxy;
    ImplementationA implA;

    function setUp() public {
        proxy = new SmallProxy();
        implA = new ImplementationA();

        proxy.setImplementation(address(implA));
    }

    function testOne() public {
        bytes memory data = proxy.getDataToTransact(777);
        console.logBytes(data);

        (bool success,) = address(proxy).call(data);
        require(success, "Call failed");

        uint256 storageVal = proxy.readStorage();
        assertEq(storageVal, uint256(777), "left and right should be equal");
    }

    function testUpgrade() public {
        ImplementationB implB = new ImplementationB();

        proxy.setImplementation(address(implB));

        bytes memory data = proxy.getDataToTransact(777);
        console.logBytes(data);

        (bool success,) = address(proxy).call(data);
        require(success, "call failed");

        uint256 storageVal = proxy.readStorage();
        assertEq(storageVal, uint256(779), "left and right should be equal");
    }
}
