// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ICLOB} from "../ICLOB.sol";

struct MakerCredit {
    address maker;
    uint256 quoteAmount;
    uint256 baseAmount;
}

// slither-disable-start assembly
library TransientMakerData {
    bytes32 constant TRANSIENT_MAKERS_POSITION =
        keccak256(abi.encode(uint256(keccak256("TransientMakers")) - 1)) & ~bytes32(uint256(0xff));
    bytes32 constant TRANSIENT_CREDITS_POSITION =
        keccak256(abi.encode(uint256(keccak256("TransientCredits")) - 1)) & ~bytes32(uint256(0xff));

    /// @dev sig: 0xe47ec074
    error ArithmeticOverflow();

    /// @dev Adds a quote token to the transient maker data
    function addQuoteToken(address maker, uint256 quoteAmount) internal {
        bytes32 slot = keccak256(abi.encode(TRANSIENT_CREDITS_POSITION, maker));
        bytes4 err = ArithmeticOverflow.selector;

        bool exists;
        assembly ("memory-safe") {
            exists := iszero(iszero(tload(slot)))

            if iszero(exists) { tstore(slot, 1) }

            let balSlot := add(slot, 1)

            let oldVal := tload(balSlot)
            let newVal := add(oldVal, quoteAmount)

            if lt(newVal, oldVal) {
                mstore(0x00, err)
                revert(0x00, 0x04)
            }

            tstore(balSlot, newVal)
        }

        if (!exists) _addMaker(maker);
    }

    /// @dev Adds a base token to the transient maker data
    function addBaseToken(address maker, uint256 baseAmount) internal {
        bytes32 slot = keccak256(abi.encode(TRANSIENT_CREDITS_POSITION, maker));
        bytes4 err = ArithmeticOverflow.selector;

        bool exists;
        assembly ("memory-safe") {
            exists := iszero(iszero(tload(slot)))

            if iszero(exists) { tstore(slot, 1) }

            let balSlot := add(slot, 2)

            let oldVal := tload(balSlot)
            let newVal := add(oldVal, baseAmount)

            if lt(newVal, oldVal) {
                mstore(0x00, err)
                revert(0x00, 0x04)
            }

            tstore(balSlot, newVal)
        }

        if (!exists) _addMaker(maker);
    }

    /// @dev Gets the maker credits and clears the storage
    function getMakerCreditsAndClearStorage() internal returns (MakerCredit[] memory makerCredits) {
        address[] memory makers = _getMakersAndClear();

        uint256 length = makers.length;

        makerCredits = new MakerCredit[](length);

        uint256 quoteAmount;
        uint256 baseAmount;

        for (uint256 i; i < length; i++) {
            (quoteAmount, baseAmount) = _getBalancesAndClear(makers[i]);

            makerCredits[i] = MakerCredit({maker: makers[i], quoteAmount: quoteAmount, baseAmount: baseAmount});
        }
    }

    function _addMaker(address maker) internal {
        bytes32 slot = TRANSIENT_MAKERS_POSITION;

        assembly ("memory-safe") {
            let len := tload(slot)

            mstore(0x00, slot)

            let dataSlot := keccak256(0x00, 0x20)

            tstore(add(dataSlot, len), maker)
            tstore(slot, add(len, 1))
        }
    }

    function _getMakersAndClear() internal returns (address[] memory makers) {
        bytes32 slot = TRANSIENT_MAKERS_POSITION;

        assembly ("memory-safe") {
            let len := tload(slot)

            makers := mload(0x40)

            mstore(makers, len)

            mstore(0x00, slot)

            let dataSlot := keccak256(0x00, 0x20)
            let memPointer := add(makers, 0x20)

            for { let i := 0 } lt(i, len) { i := add(i, 1) } {
                mstore(add(memPointer, mul(i, 0x20)), tload(add(dataSlot, i)))
                tstore(add(dataSlot, i), 0) // clear maker
            }

            mstore(0x40, add(memPointer, mul(len, 0x20))) // idk the purpose of this tbh
            tstore(slot, 0) // clear length
        }
    }

    function _getBalancesAndClear(address maker) internal returns (uint256 quoteAmount, uint256 baseAmount) {
        bytes32 slot = keccak256(abi.encode(TRANSIENT_CREDITS_POSITION, maker));

        assembly ("memory-safe") {
            let quote := add(slot, 1)
            let base := add(slot, 2)
            let instant := 0
            let account := 1

            quoteAmount := tload(quote)
            baseAmount := tload(base)

            tstore(slot, 0)
            tstore(quote, 0)
            tstore(base, 0)
        }
    }
}
// slither-disable-end assembly
