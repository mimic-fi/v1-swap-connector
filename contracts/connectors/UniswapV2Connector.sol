// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

import './BaseConnector.sol';
import '../utils/ArraysLib.sol';

abstract contract UniswapV2Connector is BaseConnector {
    using Arrays for address[];
    using SafeERC20 for IERC20;

    struct UniswapV2Path {
        address[] hopTokens;
    }

    IUniswapV2Router02 private immutable uniswapV2Router;

    mapping (bytes32 => UniswapV2Path) private _paths;

    constructor(address _uniswapV2Router) {
        uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);
    }

    function getUniswapV2Path(address tokenA, address tokenB) external view returns (UniswapV2Path memory) {
        return _paths[getPath(tokenA, tokenB)];
    }

    function setUniswapV2Path(address[] memory tokens) external onlyOwner {
        require(tokens.length >= 2, 'INVALID_UNISWAP_INPUT_LENGTH');
        address factory = uniswapV2Router.factory();
        for (uint256 i = 0; i < tokens.length - 1; i++) _validatePool(factory, tokens[i], tokens[i + 1]);

        bytes32 pathId = _setPathDex(tokens.first(), tokens.last(), DEX.UniswapV2);
        UniswapV2Path storage path = _paths[pathId];
        for (uint256 i = 2; i < tokens.length; i++) path.hopTokens.push(tokens[i - 1]);
    }

    function _swapUniswapV2(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut, uint256 deadline)
        internal
        returns (uint256 amountOut)
    {
        IERC20(tokenIn).safeApprove(address(uniswapV2Router), amountIn);
        address[] memory path = _buildPoolPath(tokenIn, tokenOut);
        uint256[] memory amounts = uniswapV2Router.swapExactTokensForTokens(
            amountIn,
            minAmountOut,
            path,
            msg.sender,
            deadline
        );
        require(amounts.length == path.length, 'UNISWAP_INVALID_RESPONSE_LENGTH');
        return amounts[1];
    }

    function _buildPoolPath(address tokenA, address tokenB) private view returns (address[] memory) {
        UniswapV2Path storage path = _paths[getPath(tokenA, tokenB)];
        address[] memory hopTokens = path.hopTokens;
        return hopTokens.isEmpty() ? Arrays.from(tokenA, tokenB) : Arrays.from(tokenA, hopTokens, tokenB);
    }

    function _validatePool(address factory, address tokenA, address tokenB) private view {
        address pool = IUniswapV2Factory(factory).getPair(tokenA, tokenB);
        require(pool != address(0), 'INVALID_UNISWAP_POOL');
    }
}
