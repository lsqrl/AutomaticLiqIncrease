// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {HookedToken} from "../src/HookedToken.sol";

contract HookedTokenTest is Test {
    HookedToken public hookedTOken;

    // arbitrum address 0xC36442b4a4522E871399CD717aBDD847Ab11FE88
    // arbitrum sepolia address 0x6b2937Bde17889EDCf8fbD8dE31C3C2a70Bc4d65

    address internal constant nonfungiblePositionManager = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88; 

    uint256 blockNumber = 199708393;
    string internal constant rpcUrl = "ARBITRUM_RPC_URL";

    function setUp() public {
        uint256 forkId = vm.createFork(vm.envString(rpcUrl), blockNumber);
        vm.selectFork(forkId);
        hookedTOken = new HookedToken(nonfungiblePositionManager); 
    }
}
