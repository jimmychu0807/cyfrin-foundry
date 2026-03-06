// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Mock is ERC20 {
    constructor(
        string memory name_,
        string memory symbol_,
        address minter,
        uint256 mintAmt
    ) ERC20(name_, symbol_) {
        _mint(minter, mintAmt);
    }

    function mint(
        address user,
        uint256 amt
    ) public {
        _mint(user, amt);
    }
}
