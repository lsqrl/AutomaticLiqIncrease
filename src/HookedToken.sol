// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import './interfaces/external/INonfungiblePositionManager.sol';

contract HookedToken is ERC20 {
    
    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    address public uniswapPool;
    uint256 public tokenId;

    constructor(address _nfpm) ERC20("HookedToken", "HT") {
        nonfungiblePositionManager = INonfungiblePositionManager(_nfpm);
    }

    function _increaseLiquidty(uint256 amount0, uint256 amount1) internal {
        INonfungiblePositionManager.IncreaseLiquidityParams memory increaseLiquidityParams = INonfungiblePositionManager.IncreaseLiquidityParams({
            tokenId: tokenId,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0,
            amount1Min: 0,
            deadline: block.timestamp
        });
        nonfungiblePositionManager.increaseLiquidity(increaseLiquidityParams);
    }

    function _update(address from, address to, uint256 value) internal override {
        // recall that the order is Uniswap -> User and afterwards User -> Uniswap
        // and Uniswap has a callback check for the tokens it receives
        // moreover, the transfer is to the recipient, but from the router
        // thus, we only insert the hook on token purchases, not sales

        // we first make the transfer normally
        super._update(from, to, value);

        if(from == uniswapPool) {
            // the user is buying tokens from Uniswap: 5% is used to increase liquidity
            // notice that this has a negative impact on the spot price
            // but a positive impact on the floor price
            uint256 tax = value / 20;
            super._update(to, address(this), tax);
            // TODO: check zero for one and put the correct values
            _increaseLiquidty(0,0);
        } 

    }
}
