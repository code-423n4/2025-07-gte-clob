import {RedBlackTree, RedBlackTreeLib, MIN, MAX} from "contracts/clob/types/RedBlackTree.sol";

contract MockTree {
    RedBlackTree tree;

    function insert(uint256 value) external {
        tree.insert(value);
    }

    function remove(uint256 value) external {
        tree.remove(value);
    }

    function size() external view returns (uint256) {
        return tree.size();
    }

    function getNextBiggest(uint256 value) external view returns (uint256) {
        return tree.getNextBiggest(value);
    }

    function getNextSmallest(uint256 value) external view returns (uint256) {
        return tree.getNextSmallest(value);
    }

    function maximum() external view returns (uint256) {
        return tree.maximum();
    }

    function minimum() external view returns (uint256) {
        return tree.minimum();
    }

    function contains(uint256 value) external view returns (bool) {
        return tree.contains(value);
    }

}
