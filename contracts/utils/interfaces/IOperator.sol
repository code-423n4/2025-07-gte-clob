// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IOperator {
    function getOperatorRoleApprovals(address account, address operator) external view returns (uint256);
    function approveOperator(address operator, uint256 roles) external;
    function disapproveOperator(address operator, uint256 roles) external;
}
