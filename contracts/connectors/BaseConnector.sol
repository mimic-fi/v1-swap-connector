// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';

/**
 * @title BaseConnector
 * @dev Base DEX connector contract, it provides a function to compute path IDs and a function to store a custom
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
     * @dev Internal function to assign a DEX for a token pair. This method must be overridden by each connector.
     * @param tokenA First token of the pair
     * @param tokenB Second token of the pair
     * @param dex DEX being set to
     */
    function _setPathDex(address tokenA, address tokenB, DEX dex) internal virtual returns (bytes32 path);

    /**
     * @dev Tells the path ID for a token pair
     * @param tokenA First token of the pair
     * @param tokenB Second token of the pair
     */
    function getPath(address tokenA, address tokenB) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(tokenA, tokenB));
    }
}
