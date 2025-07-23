// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {RedBlackTreeLib} from "@solady/utils/RedBlackTreeLib.sol";

uint256 constant MIN = 0;
uint256 constant MAX = type(uint256).max;

struct RedBlackTree {
    RedBlackTreeLib.Tree tree;
}

using BookRedBlackTreeLib for RedBlackTree global;

library BookRedBlackTreeLib {
    /// @dev sig: 0x2b72e905
    error NodeKeyInvalid();

    function size(RedBlackTree storage tree) internal view returns (uint256) {
        return RedBlackTreeLib.size(tree.tree);
    }

    /// @dev Returns the minimum value in the tree, or type(uint256).max if the tree is empty
    function minimum(RedBlackTree storage tree) internal view returns (uint256) {
        bytes32 result = RedBlackTreeLib.first(tree.tree);

        if (result == bytes32(0)) return type(uint256).max;

        return RedBlackTreeLib.value(result);
    }

    /// @dev Returns the maximum value in the tree, or type(uint256).min if the tree is empty
    function maximum(RedBlackTree storage tree) internal view returns (uint256) {
        bytes32 result = RedBlackTreeLib.last(tree.tree);

        if (result == bytes32(0)) return type(uint256).min;

        return RedBlackTreeLib.value(result);
    }

    function contains(RedBlackTree storage tree, uint256 nodeKey) internal view returns (bool) {
        return RedBlackTreeLib.exists(tree.tree, nodeKey);
    }

    /// @dev Returns the nearest key greater than `nodeKey`, checking if nodeKey exists.
    /// @dev If nodeKey is the maximum, returns MIN.
    function getNextBiggest(RedBlackTree storage tree, uint256 nodeKey) internal view returns (uint256) {
        if (nodeKey == tree.maximum()) return MAX;
        if (nodeKey == uint256(type(uint256).max)) revert NodeKeyInvalid();

        bytes32 result = RedBlackTreeLib.nearestAfter(tree.tree, nodeKey + 1);
        return RedBlackTreeLib.value(result);
    }

    /// @dev Returns the nearest key less than `nodeKey`, checking if nodeKey exists.
    /// @dev If nodeKey is the minimum, returns MAX.
    function getNextSmallest(RedBlackTree storage tree, uint256 nodeKey) internal view returns (uint256) {
        if (nodeKey == tree.minimum()) return MIN;
        if (nodeKey == 0) revert NodeKeyInvalid();

        bytes32 result = RedBlackTreeLib.nearestBefore(tree.tree, nodeKey - 1);
        return RedBlackTreeLib.value(result);
    }

    function insert(RedBlackTree storage tree, uint256 nodeKey) internal {
        RedBlackTreeLib.insert(tree.tree, nodeKey);
    }

    function remove(RedBlackTree storage tree, uint256 nodeKey) internal {
        RedBlackTreeLib.remove(tree.tree, nodeKey);
    }
}
