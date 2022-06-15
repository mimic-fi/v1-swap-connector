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

/**
 * @title UniswapV3Connector
 * @dev Interfaces with Uniswap V3 to swap tokens
 */
abstract contract UniswapV3Connector is BaseConnector {
    using Bytes for bytes;
    using Arrays for uint24[];
    using Arrays for address[];
    using SafeERC20 for IERC20;

    /**
     * @dev Internal data structure used to store UniswapV3 configurations
     * @param fee Fee value used for the corresponding path. It is set to zero if the path requires a multi-hop.
     * @param poolsPath UniswapV3-encoded path to execute the swap. It is set to zero if the path requires a single hop.
     */
    struct UniswapV3Path {
        uint24 fee;
        bytes poolsPath;
    }

    // Reference to UniswapV3 router
    ISwapRouter private immutable uniswapV3Router;

    // List of UniswapV3Path configs indexed per path ID
    mapping (bytes32 => UniswapV3Path) private _paths;

    /**
     * @dev Initializes the UniswapV3Connector contract
     * @param _uniswapV3Router Uniswap V3 router reference
     */
    constructor(address _uniswapV3Router) {
        uniswapV3Router = ISwapRouter(_uniswapV3Router);
    }

    /**
     * @dev Tells the UniswapV3 config set for a pair (tokenA, tokenB)
     * @param tokenA First token of the pair
     * @param tokenB Second token of the pair
     */
    function getUniswapV3Path(address tokenA, address tokenB) external view returns (UniswapV3Path memory) {
        return _paths[getPath(tokenA, tokenB)];
    }

    /**
     * @dev Sets a UniswapV3 config for a path
     * @param tokens List of tokens in the path
     * @param fees List of fees to be used for each tokens pair in the tokens list
     * @param bidirectional Whether the path should be applied on both sides or not
     */
    function setUniswapV3Path(address[] memory tokens, uint24[] memory fees, bool bidirectional) external onlyOwner {
        require(tokens.length >= 2 && tokens.length == fees.length + 1, 'INVALID_UNISWAP_INPUT_LENGTH');
        address factory = IPeripheryImmutableState(address(uniswapV3Router)).factory();
        for (uint256 i = 0; i < fees.length; i++) _validatePool(factory, tokens[i], tokens[i + 1], fees[i]);

        _setUniswapV3Path(tokens, fees);
        if (bidirectional) _setUniswapV3Path(tokens.reverse(), fees.reverse());
    }

    /**
     * @dev Internal function to set a UniswapV3 config for a path
     * @param tokens List of tokens in the path
     * @param fees List of fees to be used for each tokens pair in the tokens list
     */
    function _setUniswapV3Path(address[] memory tokens, uint24[] memory fees) internal {
        bytes32 pathId = _setPathDex(tokens.first(), tokens.last(), DEX.UniswapV3);
        UniswapV3Path storage path = _paths[pathId];
        bool singleSwap = fees.length == 1;
        path.fee = singleSwap ? fees[0] : 0;
        path.poolsPath = singleSwap ? new bytes(0) : _encodePoolPath(tokens, fees);
    }

    /**
     * @dev Internal function to swap two tokens through UniswapV3
     * @param tokenIn Token being sent
     * @param tokenOut Token being received
     * @param amountIn Amount of tokenIn being swapped
     * @param minAmountOut Minimum amount of tokenOut willing to receive
     * @param deadline Expiration timestamp to be used for the swap request
     */
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

    /**
     * @dev Internal function to swap two tokens through UniswapV3 using a single hop
     * @param tokenIn Token being sent
     * @param tokenOut Token being received
     * @param amountIn Amount of tokenIn being swapped
     * @param minAmountOut Minimum amount of tokenOut willing to receive
     * @param deadline Expiration timestamp to be used for the swap request
     */
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

    /**
     * @dev Internal function to swap two tokens through UniswapV3 using a multi hop
     * @param poolsPath Path of pools to implement the requested swap
     * @param amountIn Amount of the first token in the path to be swapped
     * @param minAmountOut Minimum amount of the last token in the path willing to receive
     * @param deadline Expiration timestamp to be used for the swap request
     */
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

    /**
     * @dev Internal function to validate that there is a pool created for tokenA and tokenB with a requested fee
     * @param factory UniswapV3 factory to check against
     * @param tokenA One of the tokens in the pool
     * @param tokenB The other token in the pool
     * @param fee Fee used by the pool
     */
    function _validatePool(address factory, address tokenA, address tokenB, uint24 fee) private view {
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(IUniswapV3Factory(factory).getPool(token0, token1, fee) != address(0), 'INVALID_UNISWAP_POOL_FEE');
    }

    /**
     * @dev Internal function to encode a path of tokens with their corresponding fees
     * @param tokens List of tokens to be encoded
     * @param fees List of fees to use for each token pair
     */
    function _encodePoolPath(address[] memory tokens, uint24[] memory fees) private pure returns (bytes memory path) {
        path = new bytes(0);
        for (uint256 i = 0; i < fees.length; i++) path = path.concat(tokens[i]).concat(fees[i]);
        path = path.concat(tokens[fees.length]);
    }
}
