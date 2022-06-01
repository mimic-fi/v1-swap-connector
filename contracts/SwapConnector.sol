// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@mimic-fi/v1-vault/contracts/libraries/FixedPoint.sol';
import '@mimic-fi/v1-vault/contracts/interfaces/IPriceOracle.sol';
import '@mimic-fi/v1-vault/contracts/interfaces/ISwapConnector.sol';

import './connectors/UniswapV3Connector.sol';
import './connectors/UniswapV2Connector.sol';
import './connectors/BalancerV2Connector.sol';

contract SwapConnector is ISwapConnector, UniswapV3Connector, UniswapV2Connector, BalancerV2Connector {
    using FixedPoint for uint256;

    event PathDexSet(bytes32 indexed path, address tokenA, address tokenB, DEX dex);

    IPriceOracle public immutable priceOracle;

    mapping (bytes32 => DEX) public pathDex;

    constructor(IPriceOracle _priceOracle, address uniswapV3Router, address uniswapV2Router, address balancerV2Vault)
        UniswapV3Connector(uniswapV3Router)
        UniswapV2Connector(uniswapV2Router)
        BalancerV2Connector(balancerV2Vault)
    {
        priceOracle = _priceOracle;
    }

    function getPathDex(address tokenA, address tokenB) public view returns (DEX) {
        return pathDex[getPath(tokenA, tokenB)];
    }

    function getAmountOut(address tokenIn, address tokenOut, uint256 amountIn)
        external
        view
        override
        returns (uint256)
    {
        uint256 price = priceOracle.getTokenPrice(tokenOut, tokenIn);
        return amountIn.mulUp(price);
    }

    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline,
        bytes memory /* data */
    ) external override returns (uint256 remainingIn, uint256 amountOut) {
        DEX dex = getPathDex(tokenIn, tokenOut);
        amountOut = _swap(dex, tokenIn, tokenOut, amountIn, minAmountOut, deadline);
        return (0, amountOut);
    }

    function _swap(DEX dex, address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut, uint256 deadline)
        internal
        returns (uint256)
    {
        if (dex == DEX.UniswapV2) return _swapUniswapV2(tokenIn, tokenOut, amountIn, minAmountOut, deadline);
        else if (dex == DEX.UniswapV3) return _swapUniswapV3(tokenIn, tokenOut, amountIn, minAmountOut, deadline);
        else if (dex == DEX.BalancerV2) return _swapBalancerV2(tokenIn, tokenOut, amountIn, minAmountOut, deadline);
        else revert('INVALID_DEX_OPTION');
    }

    function _setPathDex(address tokenA, address tokenB, DEX dex) internal override returns (bytes32 path) {
        path = getPath(tokenA, tokenB);
        pathDex[path] = dex;
        emit PathDexSet(path, tokenA, tokenB, dex);
    }
}
