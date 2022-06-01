// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

library Arrays {
    function isEmpty(address[] memory arr) internal pure returns (bool) {
        return arr.length == 0;
    }

    function first(address[] memory arr) internal pure returns (address) {
        return arr[0];
    }

    function last(address[] memory arr) internal pure returns (address) {
        return arr[arr.length - 1];
    }

    function from(address a, address b) internal pure returns (address[] memory result) {
        result = new address[](2);
        result[0] = a;
        result[1] = b;
    }

    function from(address a, address b, address c) internal pure returns (address[] memory result) {
        result = new address[](3);
        result[0] = a;
        result[1] = b;
        result[2] = c;
    }

    function from(address a, address[] memory b, address c) internal pure returns (address[] memory result) {
        result = new address[](b.length + 2);
        result[0] = a;
        for (uint256 i = 0; i < b.length; i++) result[i + 1] = b[i];
        result[b.length + 1] = c;
    }

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
