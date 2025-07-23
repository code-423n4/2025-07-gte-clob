// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {RedBlackTree, RedBlackTreeLib, MIN, MAX} from "contracts/clob/types/RedBlackTree.sol";
import {Test} from "forge-std/Test.sol";
contract RedBlackTreeFuzzTest is Test {
    using RedBlackTreeLib for RedBlackTree;
    RedBlackTree private tree;
    uint256[] private insertedValues;

    function testFuzz_InsertAndRemove(uint256[] memory values, uint256[] memory removeIndices) public {
        // Bound the number of operations to prevent excessively long test runs
        uint256 numOperations = bound(values.length, 1, 1000);
        values = new uint256[](numOperations);
        removeIndices = new uint256[](numOperations);

        // Insert values
        for (uint256 i = 0; i < numOperations; i++) {
            values[i] = bound(values[i], 1, type(uint256).max - 1); // Avoid inserting NULL (0)

            if (!tree.contains(values[i])) {
                tree.insert(values[i]);
                insertedValues.push(values[i]);

                assertCorrectMinMax();
                assertCorrectSize();
            }
        }

        // Remove values
        for (uint256 i = 0; i < numOperations && insertedValues.length > 0; i++) {
            uint256 indexToRemove = bound(removeIndices[i], 0, insertedValues.length - 1);
            uint256 valueToRemove = insertedValues[indexToRemove];

            tree.remove(valueToRemove);
            removeFromInsertedValues(indexToRemove);

            assertCorrectMinMax();
            assertCorrectSize();
        }
    }
    function testFuzz_GetNextBiggestAndSmallest(uint256[] memory values) public {
        // Return early if the values array is empty
        if (values.length == 0) return;
        // Bound the number of values to a reasonable range
        uint256 numValues = values.length <= 100 ? values.length : 100;
        // Insert unique values into the tree and store them in an array
        uint256[] memory localInsertedValues = new uint256[](numValues);

        uint256 insertedCount = 0;
        for (uint256 i = 0; i < numValues; i++) {
            uint256 value = bound(values[i], 1, type(uint256).max - 1); // Avoid inserting NULL (0)
            if (!tree.contains(value)) {
                tree.insert(value);
                localInsertedValues[insertedCount] = value;
                insertedCount++;
            }
        }

        // Handle the case where no values were inserted (e.g., all duplicates or zero)
        if (insertedCount == 0) return;
        // Select a random index to pick a value that is guaranteed to be in the tree
        uint256 randomIndex =
            uint256(keccak256(abi.encodePacked(block.timestamp, insertedCount, gasleft()))) % insertedCount;

        uint256 queryValue = localInsertedValues[randomIndex];

        // Get next biggest and smallest values
        uint256 nextBiggest = tree.getNextBiggest(queryValue);
        uint256 nextSmallest = tree.getNextSmallest(queryValue);

        // Verify properties of nextBiggest
        if (nextBiggest != MIN) {
            assertTrue(nextBiggest > queryValue);
            uint256 tempValue = tree.getNextSmallest(nextBiggest);
            assertEq(tempValue, queryValue);
        } else {
            assertEq(queryValue, tree.maximum());
        }

        // Verify properties of nextSmallest
        if (nextSmallest != MAX) {
            assertTrue(nextSmallest < queryValue);
            uint256 tempValue = tree.getNextBiggest(nextSmallest);
            assertEq(tempValue, queryValue);
        } else {
            assertEq(queryValue, tree.minimum());
        }
    }
    function testFuzz_ConsistencyAfterOperations(uint256[] memory values, uint256[] memory operations) public {
        uint256 numOperations = bound(operations.length, 1, 1000);
        values = new uint256[](numOperations);
        operations = new uint256[](numOperations);

        for (uint256 i = 0; i < numOperations; i++) {
            values[i] = bound(values[i], 1, type(uint256).max - 1); // Avoid inserting NULL (0)
            operations[i] = operations[i] % 2; // 0 for insert, 1 for remove

            if (operations[i] == 0) {
                if (!tree.contains(values[i])) {
                    tree.insert(values[i]);
                    insertedValues.push(values[i]);
                }
            } else {
                if (tree.contains(values[i])) {
                    tree.remove(values[i]);
                    removeFromInsertedValues(findIndex(values[i]));
                }
            }

            assertCorrectMinMax();
            assertCorrectSize();
        }
    }
    function testFuzz_RandomizedOperations(uint256[] memory values, uint8[] memory operations) public {
        if (values.length == 0 || operations.length == 0) return;
        // Ensure the arrays are of the same length
        uint256 numOperations = values.length < operations.length ? values.length : operations.length;
        if (numOperations > 1000) numOperations = 1000;
        for (uint256 i = 0; i < numOperations; i++) {
            uint256 value = bound(values[i], 1, type(uint256).max - 1);
            uint8 operation = operations[i] % 3;

            if (operation == 0) {
                // Insert operation
                if (!tree.contains(value)) {
                    tree.insert(value);
                    insertedValues.push(value);
                }
            } else if (operation == 1) {
                // Remove operation
                if (tree.contains(value)) {
                    tree.remove(value);
                    uint256 index = findIndex(value);
                    removeFromInsertedValues(index);
                }
            } else {
                // Query operation (e.g., check min/max)
                if (tree.size() > 0) {
                    uint256 min = tree.minimum();
                    uint256 max = tree.maximum();
                    assertTrue(tree.contains(min));
                    assertTrue(tree.contains(max));
                    for (uint256 j = 0; j < insertedValues.length; j++) {
                        assertTrue(insertedValues[j] >= min && insertedValues[j] <= max);
                    }
                }
            }
            // After each operation, assert invariants
            assertCorrectMinMax();
            assertCorrectSize();
        }
    }
    function assertCorrectMinMax() private view {
        if (tree.size() > 0) {
            assertTrue(tree.contains(tree.minimum()));
            assertTrue(tree.contains(tree.maximum()));
            for (uint256 i = 0; i < insertedValues.length; i++) {
                assertTrue(insertedValues[i] >= tree.minimum());
                assertTrue(insertedValues[i] <= tree.maximum());
            }
        } else {
            assertEq(tree.minimum(), type(uint256).max);
            assertEq(tree.maximum(), type(uint256).min);
        }
    }
    function assertCorrectSize() private view {
        assertEq(tree.size(), insertedValues.length);
    }
    function removeFromInsertedValues(uint256 index) private {
        insertedValues[index] = insertedValues[insertedValues.length - 1];
        insertedValues.pop();
    }
    function findIndex(uint256 value) private view returns (uint256) {
        for (uint256 i = 0; i < insertedValues.length; i++) {
            if (insertedValues[i] == value) return i;
        }
        revert("Value not found");
    }
}
