// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {EventNonceLib as OperatorEventNonce} from "./types/EventNonce.sol";

enum OperatorRoles {
    ADMIN,
    CLOB_FILL,
    CLOB_LIMIT,
    SPOT_DEPOSIT,
    SPOT_WITHDRAW,
    LAUNCHPAD_FILL
}

struct OperatorStorage {
    mapping(address account => mapping(address operator => uint256)) operatorRoleApprovals;
}

using OperatorStorageLib for OperatorStorage global;

/// @custom:storage-location erc7201:OperatorStorage
library OperatorStorageLib {
    bytes32 constant OPERATOR_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("OperatorStorage")) - 1)) & ~bytes32(uint256(0xff));

    /// @dev Gets the storage slot of the storage struct for the contract calling this library function
    // slither-disable-next-line uninitialized-storage
    function getOperatorStorage() internal pure returns (OperatorStorage storage self) {
        bytes32 position = OPERATOR_STORAGE_POSITION;

        // slither-disable-next-line assembly
        assembly {
            self.slot := position
        }
    }
}

contract Operator {
    /// @dev sig: 0xb816c81e0d2e75687754a9cb3111541c16ab454792482bf1dd02093f2203f353
    event OperatorApproved(
        uint256 indexed eventNonce, address indexed account, address indexed operator, uint256 newRoles
    );
    /// @dev sig: 0x1145ef8300109b8668d5581d376603c552d28f5aaefa3ca8fb7524286a41a7ae
    event OperatorDisapproved(
        uint256 indexed eventNonce, address indexed account, address indexed operator, uint256 removedRoles
    );

    /// @dev sig: 0x732ea322
    error OperatorDoesNotHaveRole();

    function _getOperatorStorage() internal pure returns (OperatorStorage storage self) {
        return OperatorStorageLib.getOperatorStorage();
    }

    function getOperatorRoleApprovals(address account, address operator) external view returns (uint256) {
        return _getOperatorStorage().operatorRoleApprovals[account][operator];
    }

    function approveOperator(address operator, uint256 roles) external {
        OperatorStorage storage self = _getOperatorStorage();

        uint256 approvedRoles = self.operatorRoleApprovals[msg.sender][operator];
        self.operatorRoleApprovals[msg.sender][operator] = approvedRoles | roles;

        emit OperatorApproved(OperatorEventNonce.inc(), msg.sender, operator, roles);
    }

    function disapproveOperator(address operator, uint256 roles) external {
        OperatorStorage storage self = _getOperatorStorage();

        uint256 approvedRoles = self.operatorRoleApprovals[msg.sender][operator];
        self.operatorRoleApprovals[msg.sender][operator] = approvedRoles & (~roles);

        emit OperatorDisapproved(OperatorEventNonce.inc(), msg.sender, operator, roles);
    }
}
