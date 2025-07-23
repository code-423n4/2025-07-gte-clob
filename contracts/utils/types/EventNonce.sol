// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

/**
 * @title EventNonce
 * @notice Shared event nonce management for tracking event ordering offchain
 * @dev Uses ERC-7201 specifically for shared access across a contract's inheritance graph
 */
struct EventNonceStorage {
    uint256 eventNonce;
}

/// @custom:storage-location erc7201:EventNonceStorage
library EventNonceLib {
    bytes32 constant EVENT_NONCE_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("EventNonceStorage")) - 1)) & ~bytes32(uint256(0xff));

    // slither-disable-next-line uninitialized-storage
    function getEventNonceStorage() internal pure returns (EventNonceStorage storage ds) {
        bytes32 position = EVENT_NONCE_STORAGE_POSITION;

        // slither-disable-next-line assembly
        assembly {
            ds.slot := position
        }
    }

    /// @notice Increments and returns the event nonce
    /// @return The new event nonce value
    function inc() internal returns (uint256) {
        EventNonceStorage storage ds = getEventNonceStorage();
        return ++ds.eventNonce;
    }

    /// @notice Gets the current event nonce without incrementing
    /// @return The current event nonce value
    function getCurrentNonce() internal view returns (uint256) {
        EventNonceStorage storage ds = getEventNonceStorage();
        return ds.eventNonce;
    }
}
