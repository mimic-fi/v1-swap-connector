// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeCast.sol';
import '../interfaces/IBalancerV2Vault.sol';

import './BaseConnector.sol';
import '../utils/ArraysLib.sol';
import '../utils/BytesLib.sol';

abstract contract BalancerV2Connector is BaseConnector {
    using Arrays for address[];
    using SafeERC20 for IERC20;

    struct BalancerV2Path {
        bytes32 poolId;
        address[] hopTokens;
        bytes32[] hopPoolIds;
    }

    IBalancerV2Vault private immutable balancerV2Vault;

    mapping (bytes32 => BalancerV2Path) private _paths;

    constructor(address _balancerV2Vault) {
        balancerV2Vault = IBalancerV2Vault(_balancerV2Vault);
    }

    function getBalancerV2Path(address tokenA, address tokenB) external view returns (BalancerV2Path memory) {
        return _paths[getPath(tokenA, tokenB)];
    }

    function setBalancerV2Path(address[] memory tokens, bytes32[] memory poolIds) external onlyOwner {
        require(tokens.length >= 2 && tokens.length == poolIds.length + 1, 'INVALID_BALANCER_INPUT_LENGTH');
        for (uint256 i = 0; i < poolIds.length; i++) _validatePool(poolIds[i], tokens[i], tokens[i + 1]);

        bytes32 pathId = _setPathDex(tokens.first(), tokens.last(), DEX.BalancerV2);
        BalancerV2Path storage path = _paths[pathId];
        path.poolId = poolIds[0];
        for (uint256 i = 1; i < poolIds.length; i++) {
            path.hopTokens.push(tokens[i]);
            path.hopPoolIds.push(poolIds[i]);
        }
    }

    function _swapBalancerV2(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        IERC20(tokenIn).safeApprove(address(balancerV2Vault), amountIn);
        BalancerV2Path storage path = _paths[getPath(tokenIn, tokenOut)];
        return
            path.hopTokens.isEmpty()
                ? _singleSwap(path.poolId, tokenIn, tokenOut, amountIn, minAmountOut, deadline)
                : _batchSwap(path, tokenIn, tokenOut, amountIn, minAmountOut, deadline);
    }

    function _singleSwap(
        bytes32 poolId,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) private returns (uint256 amountOut) {
        IBalancerV2Vault.SingleSwap memory swap;
        swap.poolId = poolId;
        swap.kind = IBalancerV2Vault.SwapKind.GIVEN_IN;
        swap.assetIn = tokenIn;
        swap.assetOut = tokenOut;
        swap.amount = amountIn;
        swap.userData = new bytes(0);
        return balancerV2Vault.swap(swap, _fundManagement(), minAmountOut, deadline);
    }

    function _batchSwap(
        BalancerV2Path storage path,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) private returns (uint256 amountOut) {
        // Build list of assets where tokens in and out are the first and last objects of the list respectively
        address[] memory assets = Arrays.from(tokenIn, path.hopTokens, tokenOut);

        // Build list of swap steps
        uint256 steps = assets.length - 1;
        IBalancerV2Vault.BatchSwapStep[] memory swaps = new IBalancerV2Vault.BatchSwapStep[](steps);
        for (uint256 j = 0; j < steps; j++) {
            IBalancerV2Vault.BatchSwapStep memory swap = swaps[j];
            swap.amount = j == 0 ? amountIn : 0;
            swap.poolId = j == 0 ? path.poolId : path.hopPoolIds[j - 1];
            swap.assetInIndex = j;
            swap.assetOutIndex = j + 1;
            swap.userData = new bytes(0);
        }

        // Build limits values
        int256[] memory limits = new int256[](assets.length);
        limits[0] = SafeCast.toInt256(amountIn);
        limits[limits.length - 1] = -SafeCast.toInt256(minAmountOut);

        // Swap
        int256[] memory results = balancerV2Vault.batchSwap(
            IBalancerV2Vault.SwapKind.GIVEN_IN,
            swaps,
            assets,
            _fundManagement(),
            limits,
            deadline
        );

        // Validate output
        int256 intAmountOut = results[results.length - 1];
        require(intAmountOut < 0, 'BALANCER_INVALID_BATCH_AMOUNT_OU');
        require(SafeCast.toUint256(results[0]) == amountIn, 'BALANCER_INVALID_BATCH_AMOUNT_IN');
        return uint256(-intAmountOut);
    }

    function _fundManagement() private view returns (IBalancerV2Vault.FundManagement memory) {
        return
            IBalancerV2Vault.FundManagement({
                sender: address(this),
                fromInternalBalance: false,
                recipient: payable(msg.sender),
                toInternalBalance: false
            });
    }

    function _validatePool(bytes32 poolId, address tokenA, address tokenB) private view {
        (address pool, ) = balancerV2Vault.getPool(poolId);
        require(pool != address(0), 'INVALID_BALANCER_POOL_ID');
        (address[] memory tokens, , ) = balancerV2Vault.getPoolTokens(poolId);
        require(tokens.includes(tokenA, tokenB), 'INVALID_BALANCER_POOL_TOKENS');
    }
}
