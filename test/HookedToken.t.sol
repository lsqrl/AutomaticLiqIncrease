// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {HookedToken} from "../src/HookedToken.sol";
import '@openzeppelin/contracts/interfaces/IERC20.sol';

contract HookedTokenTest is Test {
    
    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }
    
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    HookedToken public hookedToken;

    // arbitrum nfpm address 0xC36442b4a4522E871399CD717aBDD847Ab11FE88
    // sepolia nfp address 0x6b2937Bde17889EDCf8fbD8dE31C3C2a70Bc4d65
    address internal constant nonfungiblePositionManager = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88; 

    // arbitrum uniV3Factory address 0x1F98431c8aD98523631AE4a59f267346ea31F984
    // sepolia uniV3Factory address 0x248AB79Bbb9bC29bB72f7Cd42F17e054Fc40188e
    address internal constant uniV3Factory = 0x1F98431c8aD98523631AE4a59f267346ea31F984;

    // arbitrum swapRouter02 address 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45
    // sepolia swapRouter02 address 0x101F443B4d1b059569D643917553c771E1b9663E
    address internal constant swapRouter02 = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;

    // arbitrum usdt address 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9
    // sepolia usdt address ????
    address internal constant otherToken = 0xFd086bC7CD5C481DCC9C85ebE478A1C0b69FCbb9;

    address internal constant usdtWhale = 0xF977814e90dA44bFA03b6295A0616a897441aceC;

    uint256 blockNumber = 199708393;
    string internal constant rpcUrl = "ARBITRUM_RPC_URL";

    function setUp() public {
        uint256 forkId = vm.createFork(vm.envString(rpcUrl), blockNumber);
        vm.selectFork(forkId);
        hookedToken = new HookedToken(nonfungiblePositionManager, swapRouter02);

        // deploy uniswap v3 pool
        // to remember: tick spacing is the fee amount divided by 50
        // fee 500 -> tickSpacing = 10
        // fee 3000 -> tickSpacing = 60
        // fee 10000 -> tickSpacing = 200
        bool success; bytes memory data;
        (success, ) = uniV3Factory.call(
                abi.encodeWithSignature("createPool(address,address,uint24)", address(hookedToken), otherToken, 500));
        require(success, "createPool failed");

        // getPool
        (success, data) = uniV3Factory.call(
                abi.encodeWithSignature("getPool(address,address,uint24)", address(hookedToken), otherToken, 500));
        require(success, "getPool failed");
        address pool = abi.decode(data, (address));
        require(pool != address(0), "pool not found");

        // setPoolToken
        hookedToken.setPoolToken(swapRouter02,otherToken);

        // initialize pool
        (success, ) = pool.call(abi.encodeWithSignature("initialize(uint160)", 1 << 96));
        require(success, "initialize failed");

        // check new slot0
        (success, data) = pool.call(abi.encodeWithSignature("slot0()"));
        require(success, "slot0 failed");
        (uint160 sqrtPriceX96, int24 tick,,,,) = abi.decode(data, (uint160, int24, uint16, uint16, uint16, uint8));
        require(sqrtPriceX96 == 1 << 96, "sqrtPriceX96 badly initialized");
        require(tick == 0, "tick has unexpected value");

        // add liquidity
        address token0 = address(hookedToken) < otherToken ? address(hookedToken) : otherToken;
        address token1 = address(hookedToken) > otherToken ? address(hookedToken) : otherToken;
        // MAX_TICK=887272, MIN_TICK=-887272
        // but the tick must be a multiple of the tick spacing
        // therefore the maximum ticks are
        // fee 500 -> 887270
        // fee 3000 -> 887220
        // fee 10000 -> 887200
        MintParams memory mintParams = 
            MintParams({
                token0: token0,
                token1: token1,
                fee: 500,
                tickLower: 0,
                tickUpper: 887270,
                amount0Desired: 9e5 * 1e18,
                amount1Desired: 0,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });
        // mint position
        hookedToken.approve(nonfungiblePositionManager, 1e6 * 1e18);
        (success, data) = nonfungiblePositionManager.call(
                abi.encodeWithSignature("mint((address,address,uint24,int24,int24,uint256,uint256,uint256,uint256,address,uint256))", mintParams));
        require(success, "mint failed");

        hookedToken.setTokenId(1417362);
    }

    function testDeploy() public {
        assertEq(address(hookedToken.nfpm()), nonfungiblePositionManager);
    }

    function testTransfer() public {
        hookedToken.transfer(vm.addr(1), 1000 * 1e18);
        assertEq(hookedToken.balanceOf(vm.addr(1)), 1000 * 1e18);
    }

    function testIncreaseLiquidity() public {
        (bool success, ) = nonfungiblePositionManager.call(
                abi.encodeWithSignature("increaseLiquidity((uint256,uint256,uint256,uint256,uint256,uint256))", 1417362, 1e3 * 1e18, 0, 0, 0, block.timestamp));
        require(success, "increaseLiquidity failed");
    }

    function testSwap() public {
        vm.startPrank(usdtWhale);
        IERC20(otherToken).approve(swapRouter02, 1000 * 1e6);  
        ExactInputSingleParams memory params =
            ExactInputSingleParams({
                tokenIn: otherToken,
                tokenOut: address(hookedToken),
                fee: 500,
                recipient: usdtWhale,
                amountIn: 1000 * 1e6,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            });
        (bool success, bytes memory data) = swapRouter02.call(
                abi.encodeWithSignature("exactInputSingle((address,address,uint24,address,uint256,uint256,uint160))", params));
        require(success, "swap failed");
        vm.stopPrank();
        console.log("final balance of hookedToken", hookedToken.balanceOf(usdtWhale));
    }


}
