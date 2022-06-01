// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol';

import './BaseConnector.sol';
import '../utils/ArraysLib.sol';
import '../utils/BytesLib.sol';

abstract contract UniswapV3Connector is BaseConnector {
    using Bytes for bytes;
    using Arrays for address[];
    using SafeERC20 for IERC20;

    struct UniswapV3Path {
        uint24 fee;
        bytes poolsPath;
    }

    ISwapRouter private immutable uniswapV3Router;

    mapping (bytes32 => UniswapV3Path) private _paths;

    constructor(address _uniswapV3Router) {
        uniswapV3Router = ISwapRouter(_uniswapV3Router);
    }

    function getUniswapV3Path(address tokenA, address tokenB) external view returns (UniswapV3Path memory) {
        return _paths[getPath(tokenA, tokenB)];
    }

    function setUniswapV3Path(address[] memory tokens, uint24[] memory fees) external onlyOwner {
        require(tokens.length >= 2 && tokens.length == fees.length + 1, 'INVALID_UNISWAP_INPUT_LENGTH');
        address factory = IPeripheryImmutableState(address(uniswapV3Router)).factory();
        for (uint256 i = 0; i < fees.length; i++) _validatePool(factory, tokens[i], tokens[i + 1], fees[i]);

        bytes32 pathId = _setPathDex(tokens.first(), tokens.last(), DEX.UniswapV3);
        UniswapV3Path storage path = _paths[pathId];
        bool singleSwap = fees.length == 1;
        path.fee = singleSwap ? fees[0] : 0;
        path.poolsPath = singleSwap ? new bytes(0) : _encodePoolPath(tokens, fees);
    }

    function _swapUniswapV3(address tokenIn, address tokenOut, uint256 amountIn, uint256 minAmountOut, uint256 deadline)
        internal
        returns (uint256 amountOut)
    {
        IERC20(tokenIn).safeApprove(address(uniswapV3Router), amountIn);
        UniswapV3Path storage path = _paths[getPath(tokenIn, tokenOut)];
        bytes memory poolsPath = path.poolsPath;
        return
            poolsPath.isEmpty()
                ? _singleSwap(tokenIn, tokenOut, path.fee, amountIn, minAmountOut, deadline)
                : _batchSwap(poolsPath, amountIn, minAmountOut, deadline);
    }

    function _singleSwap(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) private returns (uint256 amountOut) {
        ISwapRouter.ExactInputSingleParams memory input;
        input.tokenIn = tokenIn;
        input.tokenOut = tokenOut;
        input.fee = fee;
        input.recipient = msg.sender;
        input.deadline = deadline;
        input.amountIn = amountIn;
        input.amountOutMinimum = minAmountOut;
        input.sqrtPriceLimitX96 = 0;
        return uniswapV3Router.exactInputSingle(input);
    }

    function _batchSwap(bytes memory poolsPath, uint256 amountIn, uint256 minAmountOut, uint256 deadline)
        private
        returns (uint256 amountOut)
    {
        ISwapRouter.ExactInputParams memory input;
        input.path = poolsPath;
        input.amountIn = amountIn;
        input.amountOutMinimum = minAmountOut;
        input.recipient = msg.sender;
        input.deadline = deadline;
        return uniswapV3Router.exactInput(input);
    }

    function _validatePool(address factory, address tokenA, address tokenB, uint24 fee) private view {
        (address token0, address token1) = sortPoolTokens(tokenA, tokenB);
        require(IUniswapV3Factory(factory).getPool(token0, token1, fee) != address(0), 'INVALID_UNISWAP_POOL_FEE');
    }

    function _encodePoolPath(address[] memory tokens, uint24[] memory fees) private view returns (bytes memory path) {
        path = new bytes(0);
        for (uint256 i = 0; i < fees.length; i++) path = path.concat(tokens[i]).concat(fees[i]);
        path = path.concat(tokens[fees.length]);
    }
}
