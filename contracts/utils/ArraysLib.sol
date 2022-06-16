// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

/**
 * @title Arrays
 * @dev Helper functions to operate with arrays
 */
library Arrays {
    /**
     * @dev Tells whether an array of addresses is empty or not
     */
    function isEmpty(address[] memory arr) internal pure returns (bool) {
        return arr.length == 0;
    }

    /**
     * @dev Tells the first item of an array of addresses. It does not check the array length.
     */
    function first(address[] memory arr) internal pure returns (address) {
        return arr[0];
    }

    /**
     * @dev Tells the last item of an array of addresses. It does not check the array length.
     */
    function last(address[] memory arr) internal pure returns (address) {
        return arr[arr.length - 1];
    }

    /**
     * @dev Builds an array of addresses based on the given ones
     */
    function from(address a, address b) internal pure returns (address[] memory result) {
        result = new address[](2);
        result[0] = a;
        result[1] = b;
    }

    /**
     * @dev Builds an array of addresses based on the given ones
     */
    function from(address a, address b, address c) internal pure returns (address[] memory result) {
        result = new address[](3);
        result[0] = a;
        result[1] = b;
        result[2] = c;
    }

    /**
     * @dev Builds an array of addresses based on the given ones
     */
    function from(address a, address[] memory b, address c) internal pure returns (address[] memory result) {
        result = new address[](b.length + 2);
        result[0] = a;
        for (uint256 i = 0; i < b.length; i++) result[i + 1] = b[i];
        result[b.length + 1] = c;
    }

    /**
     * @dev Tells if an array of addresses includes the given ones
     */
    function includes(address[] memory arr, address a, address b) internal pure returns (bool) {
        bool containsA;
        bool containsB;
        for (uint256 i = 0; i < arr.length; i++) {
            if (arr[i] == a) containsA = true;
            if (arr[i] == b) containsB = true;
        }
        return containsA && containsB;
    }
}
