// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title Roles
 * @notice Shared role definitions for CLOB and Account management systems
 * @dev Contains all role constants used across CLOBManager, CLOBAdminPanel, and AccountManager
 */
library Roles {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        ROLE CONSTANTS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // Factory management roles
    uint256 constant ADMIN_ROLE = 1 << 0; // _ROLE_0
    uint256 constant MARKET_CREATOR = 1 << 1; // _ROLE_1

    // Account management roles
    uint256 constant FEE_COLLECTOR = 1 << 2; // _ROLE_2
    uint256 constant FEE_TIER_SETTER = 1 << 3; // _ROLE_3
    uint256 constant MAX_LIMITS_EXEMPT_SETTER = 1 << 4; // _ROLE_4

    // CLOB management roles
    uint256 constant TICK_SIZE_SETTER = 1 << 5; // _ROLE_5
    uint256 constant MAX_LIMITS_PER_TX_SETTER = 1 << 6; // _ROLE_6
    uint256 constant MIN_LIMIT_ORDER_AMOUNT_SETTER = 1 << 7; // _ROLE_7
}
