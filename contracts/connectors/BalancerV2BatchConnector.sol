pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeCast.sol';

import '../interfaces/IBalancerV2Vault.sol';

import './BaseConnector.sol';

abstract contract BalancerV2BatchConnector is BaseConnector {
    using SafeERC20 for IERC20;

    uint256 private constant TOKEN_IN_INDEX = 0;
    uint256 private constant TOKEN_CONNECTOR_INDEX = 1;
    uint256 private constant TOKEN_OUT_INDEX = 2;

    struct BatchData {
        address tokenConnector;
        bytes32 pool1Id;
        bytes32 pool2Id;
    }

    event BalancerV2BatchPathSet(bytes32 indexed path, address tokenConnector, bytes32 pool1Id, bytes32 pool2Id);

    IBalancerV2Vault private immutable balancerV2Vault;

    mapping (bytes32 => BatchData) private _batchData;

    constructor(address _balancerV2Vault) {
        balancerV2Vault = IBalancerV2Vault(_balancerV2Vault);
    }

    function setBalancerV2BatchPath(
        address tokenA,
        address tokenConnector,
        address tokenB,
        bytes32 pool1Id,
        bytes32 pool2Id
    ) external onlyOwner {
        (address pool1, ) = balancerV2Vault.getPool(pool1Id);
        require(pool1 != address(0), 'POOL_1_DOES_NOT_EXIST');
        (address pool2, ) = balancerV2Vault.getPool(pool2Id);
        require(pool2 != address(0), 'POOL_2_DOES_NOT_EXIST');

        _setPathDex(tokenA, tokenB, DEX.BalancerV2Batch);

        bytes32 path = getPath(tokenA, tokenB);
        _batchData[path] = BatchData({ tokenConnector: tokenConnector, pool1Id: pool1Id, pool2Id: pool2Id });
        emit BalancerV2BatchPathSet(path, tokenConnector, pool1Id, pool2Id);
    }

    function _swapBalancerV2Batch(
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minAmountOut,
        uint256 deadline
    ) internal returns (uint256 amountOut) {
        BatchData memory batchData = _batchData[getPath(tokenIn, tokenOut)];

        IERC20(tokenIn).safeApprove(address(balancerV2Vault), amountIn);

        IBalancerV2Vault.FundManagement memory fund;
        fund.sender = address(this);
        fund.fromInternalBalance = false;
        fund.recipient = payable(msg.sender);
        fund.toInternalBalance = false;

        address[] memory assets = new address[](3);
        assets[TOKEN_IN_INDEX] = address(tokenIn);
        assets[TOKEN_CONNECTOR_INDEX] = address(batchData.tokenConnector);
        assets[TOKEN_OUT_INDEX] = address(tokenOut);

        IBalancerV2Vault.BatchSwapStep[] memory swaps = new IBalancerV2Vault.BatchSwapStep[](2);
        swaps[0] = IBalancerV2Vault.BatchSwapStep({
            poolId: batchData.pool1Id,
            assetInIndex: TOKEN_IN_INDEX,
            assetOutIndex: TOKEN_CONNECTOR_INDEX,
            amount: amountIn,
            userData: new bytes(0)
        });
        swaps[1] = IBalancerV2Vault.BatchSwapStep({
            poolId: batchData.pool2Id,
            assetInIndex: TOKEN_CONNECTOR_INDEX,
            assetOutIndex: TOKEN_OUT_INDEX,
            amount: 0,
            userData: new bytes(0)
        });

        int256[] memory limits = new int256[](3);
        limits[TOKEN_IN_INDEX] = SafeCast.toInt256(amountIn);
        limits[TOKEN_OUT_INDEX] = -SafeCast.toInt256(minAmountOut);

        int256[] memory results = balancerV2Vault.batchSwap(
            IBalancerV2Vault.SwapKind.GIVEN_IN,
            swaps,
            assets,
            fund,
            limits,
            deadline
        );

        return SafeCast.toUint256(-results[TOKEN_OUT_INDEX]);
    }
}
