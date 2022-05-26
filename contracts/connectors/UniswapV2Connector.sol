pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';

import './BaseConnector.sol';

abstract contract UniswapV2Connector is BaseConnector {
    using SafeERC20 for IERC20;

    event UniswapV2PathSet(bytes32 indexed path);

    IUniswapV2Router02 internal immutable uniswapV2Router;

    constructor (address _uniswapV2Router) {
        uniswapV2Router = IUniswapV2Router02(_uniswapV2Router);
    }

    function setUniswapV2Path(address tokenA, address tokenB) external onlyOwner {
        IUniswapV2Factory factory = IUniswapV2Factory(uniswapV2Router.factory());
        address pool = factory.getPair(tokenA, tokenB);
        require(pool != address(0), 'POOL_DOES_NOT_EXIST');

        _setPathDex(tokenA, tokenB, DEX.UniswapV2);

        bytes32 path = getPath(tokenA, tokenB);
        emit UniswapV2PathSet(path);
    }

    function _swapUniswapV2(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        IERC20(tokenIn).safeApprove(address(uniswapV2Router), amountIn);
        address[] memory path = _path(tokenIn, tokenOut);
        uint256[] memory amounts = uniswapV2Router.swapExactTokensForTokens(amountIn, minAmountOut, path, msg.sender, deadline);
        require(amounts.length == 2, 'UNISWAP_INVALID_RESPONSE_LENGTH');
        return amounts[1];
    }

    function _path(address tokenA, address tokenB) private pure returns (address[] memory path) {
        path = new address[](2);
        path[0] = tokenA;
        path[1] = tokenB;
    }
}
