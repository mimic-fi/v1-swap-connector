pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/IPeripheryImmutableState.sol';

import './BaseConnector.sol';

abstract contract UniswapV3Connector is BaseConnector {
    using SafeERC20 for IERC20;

    event UniswapV3PathSet(bytes32 indexed path, uint24 fee);

    ISwapRouter internal immutable uniswapV3Router;

    mapping (bytes32 => uint24) internal _fees;

    constructor (address _uniswapV3Router) {
        uniswapV3Router = ISwapRouter(_uniswapV3Router);
    }

    function setUniswapV3Path(address tokenA, address tokenB, uint24 fee) external onlyOwner {
        address factory = IPeripheryImmutableState(address(uniswapV3Router)).factory();
        (address token0, address token1) = sortPoolTokens(tokenA, tokenB);
        require(IUniswapV3Factory(factory).getPool(token0, token1, fee) != address(0), 'POOL_FEE_DOES_NOT_EXIST');

        _setPathDex(tokenA, tokenB, DEX.UniswapV3);

        bytes32 path = getPath(tokenA, tokenB);
        _fees[path] = fee;
        emit UniswapV3PathSet(path, fee);
    }

    function _swapUniswapV3(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        IERC20(tokenIn).safeApprove(address(uniswapV3Router), amountIn);
        ISwapRouter.ExactInputSingleParams memory input;
        input.tokenIn = tokenIn;
        input.tokenOut = tokenOut;
        input.fee = _fees[getPath(tokenIn, tokenOut)];
        input.recipient = msg.sender;
        input.deadline = deadline;
        input.amountIn = amountIn;
        input.amountOutMinimum = minAmountOut;
        input.sqrtPriceLimitX96 = 0;
        return uniswapV3Router.exactInputSingle(input);
    }
}