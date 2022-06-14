// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';

/**
 * @title BaseConnector
 * @dev Base AMM connector contract, it provides a few helper functions and the common function to store a custom
 *      path that must be implemented by each connector
 */
abstract contract BaseConnector is Ownable {
    /**
     * @dev Enum identifying the DEXes supported by this implementation: Uniswap V2, Uniswap V3, and Balancer V2.
     *      Note that Uniswap V2 will be used by default and more customization could be added in the future.
     */
    enum DEX {
        UniswapV2,
        UniswapV3,
        BalancerV2
    }

    /**
     * @dev Internal function to set a custom path for a token pair. This method must be overridden by each connector.
     * @param tokenA One of the tokens of the pair
     * @param tokenB The other token of the pair
     * @param dex DEX being set to
     */
    function _setPathDex(address tokenA, address tokenB, DEX dex) internal virtual returns (bytes32 path);

    /**
     * @dev Sorts a token pair
     * @param tokenA One of the tokens of the pair
     * @param tokenB The other token of the pair
     */
    function sortPoolTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    /**
     * @dev Tells the path ID for a token pair
     * @param tokenA One of the tokens of the pair
     * @param tokenB The other token of the pair
     */
    function getPath(address tokenA, address tokenB) public pure returns (bytes32) {
        (address token0, address token1) = sortPoolTokens(tokenA, tokenB);
        return keccak256(abi.encodePacked(token0, token1));
    }
}
