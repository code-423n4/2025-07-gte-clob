// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IOperator} from "../interfaces/IOperator.sol";
import {OperatorRoles, OperatorStorage} from "../Operator.sol";

library OperatorHelperLib {
    /// @dev sig: 0x732ea322
    error OperatorDoesNotHaveRole();

    function assertHasRole(uint256 rolesPacked, OperatorRoles role) internal pure {
        if (rolesPacked & 1 << uint8(role) == 0 && rolesPacked & 1 == 0) revert OperatorDoesNotHaveRole();
    }

    /// @dev Performs operator check with both operator and router bypass
    function onlySenderOrOperator(IOperator operator, address gteRouter, address account, OperatorRoles requiredRole)
        internal
        view
    {
        if (msg.sender == account || msg.sender == gteRouter) return;

        uint256 rolesPacked = operator.getOperatorRoleApprovals(account, msg.sender);
        assertHasRole(rolesPacked, requiredRole);
    }

    /// @dev Performs operator check with just operator
    function onlySenderOrOperator(IOperator operator, address account, OperatorRoles requiredRole) internal view {
        if (msg.sender == account) return;

        uint256 rolesPacked = operator.getOperatorRoleApprovals(account, msg.sender);
        assertHasRole(rolesPacked, requiredRole);
    }

    /// @dev Performs operator check with storage directly (for contracts inheriting Operator)
    function onlySenderOrOperator(
        OperatorStorage storage operatorStorage,
        address gteRouter,
        address account,
        OperatorRoles requiredRole
    ) internal view {
        if (msg.sender == account || msg.sender == gteRouter) return;

        uint256 rolesPacked = operatorStorage.operatorRoleApprovals[account][msg.sender];
        assertHasRole(rolesPacked, requiredRole);
    }
}
