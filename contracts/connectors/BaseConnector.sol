// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/access/Ownable.sol';

abstract contract BaseConnector is Ownable {
    enum DEX {
        UniswapV2,
        UniswapV3,
        BalancerV2
    }

    function _setPathDex(address tokenA, address tokenB, DEX dex) internal virtual returns (bytes32 path);

    function sortPoolTokens(address tokenA, address tokenB) public pure returns (address token0, address token1) {
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
    }

    function getPath(address tokenA, address tokenB) public pure returns (bytes32) {
        (address token0, address token1) = sortPoolTokens(tokenA, tokenB);
        return keccak256(abi.encodePacked(token0, token1));
    }
}
