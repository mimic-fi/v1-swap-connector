// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

import './BaseConnector.sol';
import '../utils/ArraysLib.sol';

/**
 * @title UniswapV2Connector
 * @dev Interfaces with Uniswap V2 to swap tokens
 */
abstract contract UniswapV2Connector is BaseConnector {
    using Arrays for address[];
    using SafeERC20 for IERC20;

    /**
     * @dev Internal data structure used to store UniswapV3 configurations
     * @param hopTokens List of tokens to hop with to execute a swap, if empty it means the target is the pool itself.
     */
    struct UniswapV2Path {
        address[] hopTokens;
    }

    // Reference to UniswapV3 router
    IUniswapV2Router02 private immutable uniswapV2Router;

    // List of UniswapV2Path configs indexed per path ID
    mapping (bytes32 => UniswapV2Path) private _paths;

    /**
     * @dev Initializes the UniswapV2Connector contract
     * @param _uniswapV2Router Uniswap V2 router reference
     */
    constructor(address _uniswapV2Router) {
        uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);
    }

    /**
     * @dev Tells the UniswapV2 config set for a path (tokenA, tokenB)
     * @param tokenA One of the tokens in the path
     * @param tokenB The other token in the path
     */
    function getUniswapV2Path(address tokenA, address tokenB) external view returns (UniswapV2Path memory) {
        return _paths[getPath(tokenA, tokenB)];
    }

    /**
     * @dev Sets a UniswapV2 config for a path
     * @param tokens Bidirectional list of tokens in the path
     */
    function setUniswapV2Path(address[] memory tokens) external onlyOwner {
        require(tokens.length >= 2, 'INVALID_UNISWAP_INPUT_LENGTH');
        address factory = uniswapV2Router.factory();
        for (uint256 i = 0; i < tokens.length - 1; i++) _validatePool(factory, tokens[i], tokens[i + 1]);

        bytes32 pathId = _setPathDex(tokens.first(), tokens.last(), DEX.UniswapV2);
        UniswapV2Path storage path = _paths[pathId];
        for (uint256 i = 2; i < tokens.length; i++) path.hopTokens.push(tokens[i - 1]);
    }

    /**
     * @dev Internal function to swap two tokens through UniswapV2
     * @param tokenIn Token being sent
     * @param tokenOut Token being received
     * @param amountIn Amount of tokenIn being swapped
     * @param minAmountOut Minimum amount of tokenOut willing to receive
     * @param deadline Expiration timestamp to be used for the swap request
     */
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

    /**
     * @dev Internal method to fetch the path between two tokens based on the config set
     * @param tokenA One of the tokens in the path
     * @param tokenB The other token in the path
     */
    function _buildPoolPath(address tokenA, address tokenB) private view returns (address[] memory) {
        UniswapV2Path storage path = _paths[getPath(tokenA, tokenB)];
        address[] memory hopTokens = path.hopTokens;
        return hopTokens.isEmpty() ? Arrays.from(tokenA, tokenB) : Arrays.from(tokenA, hopTokens, tokenB);
    }

    /**
     * @dev Internal function to validate that there is a pool created for tokenA and tokenB
     * @param factory UniswapV2 factory to check against
     * @param tokenA One of the tokens in the pool
     * @param tokenB The other token in the pool
     */
    function _validatePool(address factory, address tokenA, address tokenB) private view {
        address pool = IUniswapV2Factory(factory).getPair(tokenA, tokenB);
        require(pool != address(0), 'INVALID_UNISWAP_POOL');
    }
}
