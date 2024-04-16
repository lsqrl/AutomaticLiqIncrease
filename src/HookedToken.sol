// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './interfaces/external/INonfungiblePositionManager.sol';

import {console} from 'forge-std/console.sol';

contract HookedToken is ERC20, Ownable {

    INonfungiblePositionManager public immutable nfpm;

    mapping (address => address) public poolToken;
    mapping (address => bool) public isAddressExcluded;
    uint256 public tokenId;

    constructor(address _nfpm) ERC20("HookedToken", "HT") Ownable(msg.sender) {
        _mint(msg.sender, 1000000 * 10 ** 18);
        nfpm = INonfungiblePositionManager(_nfpm);
    }

    function setAddressExclusionPolicy(address addr, bool excluded) public onlyOwner {
        isAddressExcluded[addr] = excluded;
    }

    function setPoolToken(address pool, address otherToken) public onlyOwner {
        poolToken[pool] = otherToken;
    }

    function setTokenId(uint256 _tokenId) public onlyOwner {
        tokenId = _tokenId;
    }

    function _increaseLiquidty(address otherToken, uint256 amount) internal {
        // Tokens are put in alphabetical orders on the addresses by the UniV3 factory
        // Therefore we need to understand whether our token is 0 or 1
        uint256 amount0 = address(this) < otherToken ? amount : 0;
        uint256 amount1 = address(this) > otherToken ? amount : 0;
        // equality cannot occur since tokens in a pool are different (ref UniV3 factory)
        INonfungiblePositionManager.IncreaseLiquidityParams memory increaseLiquidityParams = 
            INonfungiblePositionManager.IncreaseLiquidityParams({
                tokenId: tokenId,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                deadline: block.timestamp
            });
        nfpm.increaseLiquidity(increaseLiquidityParams);
    }

    function _update(address from, address to, uint256 value) internal override {
        // recall that the order is Uniswap -> User and afterwards User -> Uniswap
        // and Uniswap has a callback check for the tokens it receives
        // moreover, the transfer is to the recipient, but from the router
        // thus, we only insert the hook on token purchases, not sales
        super._update(from, to, value);
    }

    function decimals() public pure override returns (uint8) {
        return 6;
    }
}
