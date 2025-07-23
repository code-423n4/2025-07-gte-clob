// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {OperatorRoles, Operator} from "contracts/utils/Operator.sol";
import {OperatorHelperLib} from "contracts/utils/types/OperatorHelperLib.sol";
import "forge-std/console.sol";
import "forge-std/Test.sol";

/// @notice This contract tests the operator functionality
contract OperatorTest is Test {
    Operator public operator;

    function setUp() public {
        operator = new Operator();
    }

    /// @dev it's more about making sure that `account` is not one of the contracts used in the test suite,
    ///      than it actually being an EOA
    function _assumeEOA(address account) internal view {
        vm.assume(account != address(0) && account.code.length == 0);
    }

    function testFuzz_disapprove_operator(address account, address operatorAddr) public {
        _assumeEOA(account);
        _assumeEOA(operatorAddr);

        vm.startPrank(account);
        operator.approveOperator(operatorAddr, 1);
        assertTrue(operator.getOperatorRoleApprovals(account, operatorAddr) == 1);

        // TODO: Update event expectation for new operator contract
        // vm.expectEmit();
        // emit OperatorDisapproved(operator.getEventNonce() + 1, account, operatorAddr, 1);
        operator.disapproveOperator(operatorAddr, 1);
        uint256 roles = operator.getOperatorRoleApprovals(account, operatorAddr);

        assertEq(roles, 0);
        vm.stopPrank();
    }

    function testFuzz_approve_operator(address account, address operatorAddr) public {
        _assumeEOA(account);
        _assumeEOA(operatorAddr);
        vm.startPrank(account);

        assertEq(operator.getOperatorRoleApprovals(account, operatorAddr), 0);

        operator.approveOperator(operatorAddr, 1);
        assertEq(operator.getOperatorRoleApprovals(account, operatorAddr), 1);
    }
}