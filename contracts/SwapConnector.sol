// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import '@mimic-fi/v1-helpers/contracts/math/FixedPoint.sol';
import '@mimic-fi/v1-price-oracle/contracts/IPriceOracle.sol';

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './ISwapConnector.sol';
import './connectors/UniswapV3Connector.sol';
import './connectors/UniswapV2Connector.sol';
import './connectors/BalancerV2Connector.sol';

/**
 * @title SwapConnector
 * @dev This is a pre-set DEX aggregator. Currently, it interfaces with Uniswap V2, Uniswap V3, and Balancer V2.
 *      Exchange paths can be pre-set to tell the swap connector which DEX must be used. These paths can bet set/unset
 *      at any time, and Uniswap V2 is being used by default.
 */
contract SwapConnector is ISwapConnector, UniswapV3Connector, UniswapV2Connector, BalancerV2Connector {
    using FixedPoint for uint256;

    /**
     * @dev Emitted every time a new path is set
     */
    event PathDexSet(bytes32 indexed path, address tokenA, address tokenB, DEX dex);

    // Price oracle reference to be used to validate slippage
    IPriceOracle public immutable priceOracle;

    // List of DEXes indexed by path ID
    mapping (bytes32 => DEX) public pathDex;

    /**
     * @dev Initializes the SwapConnector contract
     * @param _priceOracle Price oracle reference
     * @param uniswapV3Router Uniswap V3 router reference
     * @param uniswapV2Router Uniswap V2 router reference
     * @param balancerV2Vault Balancer V2 vault reference
     */
    constructor(IPriceOracle _priceOracle, address uniswapV3Router, address uniswapV2Router, address balancerV2Vault)
        UniswapV3Connector(uniswapV3Router)
        UniswapV2Connector(uniswapV2Router)
        BalancerV2Connector(balancerV2Vault)
    {
        priceOracle = _priceOracle;
    }

    /**
     * @dev Tells the DEX set for a path given a pair (tokenA, tokenB)
     * @param tokenA First token of the pair
     * @param tokenB Second token of the pair
     */
    function getPathDex(address tokenA, address tokenB) public view returns (DEX) {
        return pathDex[getPath(tokenA, tokenB)];
    }

    /**
     * @dev Swaps two tokens
     * @param tokenIn Token being sent
     * @param tokenOut Token being received
     * @param amountIn Amount of tokenIn being swapped
     * @param minAmountOut Minimum amount of tokenOut willing to receive
     */
    function swap(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        bytes memory /* data */
    ) external override returns (uint256 amountOut) {
        DEX dex = getPathDex(tokenIn, tokenOut);
        amountOut = _swap(dex, tokenIn, tokenOut, amountIn, minAmountOut, block.timestamp);
    }

    /**
     * @dev Internal function to swaps two tokens. It will dispatch the request to the corresponding DEX set.
     */
    function _swap(DEX dex, address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut, uint256 deadline)
        internal
        returns (uint256)
    {
        if (dex == DEX.UniswapV2) return _swapUniswapV2(tokenIn, tokenOut, amountIn, minAmountOut, deadline);
        else if (dex == DEX.UniswapV3) return _swapUniswapV3(tokenIn, tokenOut, amountIn, minAmountOut, deadline);
        else if (dex == DEX.BalancerV2) return _swapBalancerV2(tokenIn, tokenOut, amountIn, minAmountOut, deadline);
        else revert('INVALID_DEX_OPTION');
    }

    /**
     * @dev Internal function to set a DEX for a path given a pair (tokenA, tokenB)
     * @return path ID of the path being set
     */
    function _setPathDex(address tokenA, address tokenB, DEX dex) internal override returns (bytes32 path) {
        path = getPath(tokenA, tokenB);
        pathDex[path] = dex;
        emit PathDexSet(path, tokenA, tokenB, dex);
    }
}
