pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '../interfaces/IBalancerV2Vault.sol';

import './BaseConnector.sol';

abstract contract BalancerV2Connector is BaseConnector {
    using SafeERC20 for IERC20;

    event BalancerV2PathSet(bytes32 indexed path, bytes32 poolId);

    IBalancerV2Vault private immutable balancerV2Vault;

    mapping (bytes32 => bytes32) private _poolIds;

    constructor(address _balancerV2Vault) {
        balancerV2Vault = IBalancerV2Vault(_balancerV2Vault);
    }

    function setBalancerV2Path(address tokenA, address tokenB, bytes32 poolId) external onlyOwner {
        (address pool, ) = balancerV2Vault.getPool(poolId);
        require(pool != address(0), 'POOL_DOES_NOT_EXIST');

        _setPathDex(tokenA, tokenB, DEX.BalancerV2);

        bytes32 path = getPath(tokenA, tokenB);
        _poolIds[path] = poolId;
        emit BalancerV2PathSet(path, poolId);
    }

    function _swapBalancerV2(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        IERC20(tokenIn).safeApprove(address(balancerV2Vault), amountIn);

        IBalancerV2Vault.FundManagement memory fund;
        fund.sender = address(this);
        fund.fromInternalBalance = false;
        fund.recipient = payable(msg.sender);
        fund.toInternalBalance = false;

        IBalancerV2Vault.SingleSwap memory swap;
        swap.poolId = _poolIds[getPath(tokenIn, tokenOut)];
        swap.kind = IBalancerV2Vault.SwapKind.GIVEN_IN;
        swap.assetIn = tokenIn;
        swap.assetOut = tokenOut;
        swap.amount = amountIn;
        swap.userData = new bytes(0);

        return balancerV2Vault.swap(swap, fund, minAmountOut, deadline);
    }
}
