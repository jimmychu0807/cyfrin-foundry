// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import {
    OwnableUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract BoxV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 internal number;

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }

    function getNumber() external view returns (uint256) {
        return number;
    }

    function version() external pure returns (uint256) {
        return 1;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override {}
}

contract BoxV2 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    uint256 internal number;

    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }

    function setNumber(
        uint256 _number
    ) external {
        number = _number;
    }

    function getNumber() external view returns (uint256) {
        return number;
    }

    function version() external pure returns (uint256) {
        return 2;
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal override {}
}
