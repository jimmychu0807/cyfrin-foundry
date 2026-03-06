// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {
    ERC20Burnable,
    ERC20
} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * This is the contract meant to be governed by DSCEngine
 */
contract DecentralizedStableCoin is ERC20Burnable, Ownable {
    /////////////////
    // Errors
    /////////////////
    error DecentralizedStableCoin__MustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor(
        address initialOwner
    ) ERC20("DecentralizedStableCoin", "DSC") Ownable(initialOwner) {}

    function burn(
        uint256 _amount
    ) public override onlyOwner {
        require(_amount > 0, DecentralizedStableCoin__MustBeMoreThanZero());

        uint256 balance = balanceOf(msg.sender);
        require(_amount <= balance, DecentralizedStableCoin__BurnAmountExceedsBalance());

        super.burn(_amount);
    }

    function mint(
        address _to,
        uint256 _amount
    ) external onlyOwner returns (bool) {
        require(_to != address(0), DecentralizedStableCoin__NotZeroAddress());
        require(_amount > 0, DecentralizedStableCoin__MustBeMoreThanZero());

        _mint(_to, _amount);
        return true;
    }
}
