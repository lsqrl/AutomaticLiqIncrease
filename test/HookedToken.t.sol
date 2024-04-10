// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {HookedToken} from "../src/HookedToken.sol";

contract HookedTokenTest is Test {
    HookedToken public hookedTOken;

    function setUp() public {
        hookedTOken = new HookedToken();
    }
}
