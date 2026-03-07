//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";

contract MyContract1 {
    uint256 public shouldAlwaysBeZero = 0;
    uint256 hiddenValue = 0;

    function doStuff(
        uint256 data
    ) public {
        // if (data == 2) {
        //     shouldAlwaysBeZero = 1;
        // }
        if (hiddenValue == 7) {
            shouldAlwaysBeZero = 1;
        }
        hiddenValue = data;
    }
}

contract MyContract1Test is StdInvariant, Test {
    MyContract1 myContract;

    function setUp() public {
        myContract = new MyContract1();
        targetContract(address(myContract));
    }

    function testFuzz_AlwaysGetZero(
        uint256 data
    ) public {
        myContract.doStuff(data);
        assert(myContract.shouldAlwaysBeZero() == 0);
    }

    // function invariant_testAlwaysReturnsZero() public view {
    //     assert(myContract.shouldAlwaysBeZero() == 0);
    // }
}
