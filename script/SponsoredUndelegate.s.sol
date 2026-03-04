// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Vm} from "forge-std/Vm.sol";

contract SponsoredUndelegationScript is Script {
    function setUp() public {}

    function run() public {
        uint256 userSk = vm.envUint("USER_SK");
        uint256 sponsorSk = vm.envUint("SPONSOR_SK");

        address user = vm.addr(userSk);
        address sponsor = vm.addr(sponsorSk);

        console.log("user:    %s", user);
        console.log("sponsor: %s", sponsor);

        vm.startPrank(user);
        Vm.SignedDelegation memory revocation = vm.signDelegation(address(0), userSk);

        vm.stopPrank();

        vm.startBroadcast(sponsorSk);
        vm.attachDelegation(revocation);

        (bool ok,) = sponsor.call("");
        require(ok, "undelegation failed");

        bytes memory code = user.code;
        require(code.length == 0, "It is not delegated yet");

        vm.stopBroadcast();
    }
}
