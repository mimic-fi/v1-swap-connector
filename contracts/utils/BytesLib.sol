// SPDX-License-Identifier: GPL-3.0-or-later

pragma solidity ^0.8.0;

library Bytes {
    function isEmpty(bytes memory self) internal pure returns (bool) {
        return self.length == 0;
    }

    function concat(bytes memory self, address value) internal pure returns (bytes memory) {
        return abi.encodePacked(self, value);
    }

    function concat(bytes memory self, uint24 value) internal pure returns (bytes memory) {
        return abi.encodePacked(self, value);
    }
}
