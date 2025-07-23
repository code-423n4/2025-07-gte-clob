// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {MockTree} from "test/mocks/MockTree.sol";

import {RedBlackTree, RedBlackTreeLib, MIN, MAX} from "contracts/clob/types/RedBlackTree.sol";
import {RedBlackTreeLib as SoladyRedBlackTreeLib} from "@solady/utils/RedBlackTreeLib.sol";
import {Test} from "forge-std/Test.sol";

contract RedBlackTreeTest is Test {
    MockTree tree;

    function setUp() public {
        tree = new MockTree();
    }

    function testInsert() public {
        tree.insert(5);

        assertEq(tree.size(), 1);
        assertEq(tree.minimum(), 5);
        assertEq(tree.maximum(), 5);

        tree.insert(3);
        tree.insert(7);

        assertEq(tree.size(), 3);
        assertEq(tree.minimum(), 3);
        assertEq(tree.maximum(), 7);
    }

    function testInsertDuplicate() public {
        tree.insert(5);
        vm.expectRevert(SoladyRedBlackTreeLib.ValueAlreadyExists.selector);
        tree.insert(5);
    }

    function testInsertNull() public {
        vm.expectRevert(SoladyRedBlackTreeLib.ValueIsEmpty.selector);
        tree.insert(MIN);
    }

    function testRemove() public {
        tree.insert(5);
        tree.insert(3);
        tree.insert(7);

        tree.remove(5);

        assertEq(tree.size(), 2);
        assertTrue(!tree.contains(5));

        tree.remove(3);

        assertEq(tree.size(), 1);
        assertEq(tree.minimum(), 7);
        assertEq(tree.maximum(), 7);

        tree.remove(7);

        assertEq(tree.size(), 0);
    }

    function testRemoveNonExistent() public {
        vm.expectRevert(SoladyRedBlackTreeLib.ValueDoesNotExist.selector);
        tree.remove(5);
    }

    function testContains() public {
        tree.insert(5);
        assertTrue(tree.contains(5));
        assertTrue(!tree.contains(3));
    }

    function testGetNextBiggest() public {
        tree.insert(5);
        tree.insert(3);
        tree.insert(7);
        tree.insert(1);
        tree.insert(9);

        assertEq(tree.getNextBiggest(3), 5);
        assertEq(tree.getNextBiggest(5), 7);
        assertEq(tree.getNextBiggest(9), MAX);
    }

    function testGetNextBiggestEmpty() public {
        tree.insert(5);
        tree.insert(10);
        assertEq(MAX, tree.getNextBiggest(10)); // 7 doesn't exist in the tree
    }

    function testGetNextSmallest() public {
        tree.insert(5);
        tree.insert(3);
        tree.insert(7);
        tree.insert(1);
        tree.insert(9);

        assertEq(tree.getNextSmallest(5), 3);
        assertEq(tree.getNextSmallest(3), 1);
        assertEq(tree.getNextSmallest(1), MIN); // 1 is the minimum, so next smallest is MAX
    }

    function testGetNextSmallestEmpty() public {
        tree.insert(5);
        tree.insert(10);
        assertEq(MIN, tree.getNextSmallest(5)); // less than 5 does not exist
    }

    function testGetNextSmallestWithParentTraversal() public {
        // Create a tree structure that will force parent traversal
        //       8
        //      / \
        //     4   12
        //    / \    \
        //   2   6    14
        //      /
        //     5
        tree.insert(8);
        tree.insert(4);
        tree.insert(12);
        tree.insert(2);
        tree.insert(6);
        tree.insert(14);
        tree.insert(5);

        // Test the case where we need to traverse up to find the next smallest
        assertEq(tree.getNextSmallest(8), 6);
        assertEq(tree.getNextSmallest(6), 5);
        assertEq(tree.getNextSmallest(12), 8);
        assertEq(tree.getNextSmallest(14), 12);
        // Test cases that will exercise the while loop
        assertEq(tree.getNextSmallest(5), 4);
        assertEq(tree.getNextSmallest(4), 2);
    }

    function testLargeInsertionAndRemoval() public {
        uint256[] memory values = new uint256[](100);

        for (uint256 i = 0; i < 100; i++) {
            values[i] = i + 1;
        }

        // Shuffle the array
        for (uint256 i = 0; i < values.length; i++) {
            uint256 j = i + (uint256(keccak256(abi.encodePacked(block.timestamp, i))) % (values.length - i));
            (values[i], values[j]) = (values[j], values[i]);
        }

        // Insert values
        for (uint256 i = 0; i < values.length; i++) {
            tree.insert(values[i]);
        }

        assertEq(tree.size(), 100);
        assertEq(tree.minimum(), 1);
        assertEq(tree.maximum(), 100);

        // Remove values
        for (uint256 i = 0; i < values.length; i++) {
            tree.remove(values[i]);
        }

        assertEq(tree.size(), 0);
    }

    function testMinimumMaximum() public {
        // Test with empty tree
        // assertEq(tree.minimum, MIN);
        // assertEq(tree.maximum, type(uint256).min);
        // Insert and remove minimum
        tree.insert(5);
        assertEq(tree.minimum(), 5);

        tree.insert(3);
        assertEq(tree.minimum(), 3);

        tree.remove(3);
        assertEq(tree.minimum(), 5);
        // Insert and remove maximum
        assertEq(tree.maximum(), 5);

        tree.insert(7);
        assertEq(tree.maximum(), 7);

        tree.remove(7);
        assertEq(tree.maximum(), 5);
    }

    function testMultipleRotations() public {
        // This sequence should cause multiple rotations
        tree.insert(10);
        tree.insert(20);
        tree.insert(30);
        tree.insert(40);
        tree.insert(50);
        // Remove nodes to cause more rotations
        tree.remove(30);
        tree.remove(10);
    }
    function testEdgeCasesNextBiggestSmallest() public {
        tree.insert(10);
        tree.insert(5);
        tree.insert(15);
        tree.insert(3);
        tree.insert(7);
        tree.insert(12);
        tree.insert(17);

        // Test getNextBiggest
        assertEq(tree.getNextBiggest(3), 5);
        assertEq(tree.getNextBiggest(7), 10);
        assertEq(tree.getNextBiggest(10), 12);
        assertEq(tree.getNextBiggest(17), MAX);

        // Test getNextSmallest
        assertEq(tree.getNextSmallest(17), 15);
        assertEq(tree.getNextSmallest(10), 7);
        assertEq(tree.getNextSmallest(5), 3);
        assertEq(tree.getNextSmallest(3), MIN);
    }

    function testInsertAscendingOrder() public {
        for (uint256 i = 1; i <= 100; i++) {
            tree.insert(i);
        }

        assertEq(tree.size(), 100);
    }

    function testInsertDescendingOrder() public {
        for (uint256 i = 100; i > 0; i--) {
            tree.insert(i);
        }

        assertEq(tree.size(), 100);
    }

    function testComplexInsertionDeletion() public {
        uint256[] memory values = new uint256[](50);

        for (uint256 i = 0; i < 50; i++) {
            values[i] = i + 1;
        }

        // Insert all values
        for (uint256 i = 0; i < values.length; i++) {
            tree.insert(values[i]);
        }

        // Remove odd numbers
        for (uint256 i = 0; i < values.length; i += 2) {
            tree.remove(values[i]);
        }

        // Insert new values
        for (uint256 i = 51; i <= 75; i++) {
            tree.insert(i);
        }

        // Remove even numbers less than 50
        for (uint256 i = 2; i <= 50; i += 2) {
            tree.remove(i);
        }

        assertEq(tree.size(), 25);
    }

    function testExtremeValueInsertions() public {
        uint256 minValue = 1;
        uint256 maxValue = MAX;

        tree.insert(minValue);
        tree.insert(maxValue);
        
        assertTrue(tree.contains(minValue));
        assertTrue(tree.contains(maxValue));
        assertEq(tree.minimum(), minValue);
        assertEq(tree.maximum(), maxValue);
    }
}
