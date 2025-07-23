// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {EventNonceLib as FeeDataEventNonce} from "contracts/utils/types/EventNonce.sol";

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";

type PackedFeeRates is uint256;

using PackedFeeRatesLib for PackedFeeRates global;

library PackedFeeRatesLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev sig: 0x39bdbb10
    error FeeTiersExceedsMax();
    /// @dev sig: 0x8e516923
    error FeeTierIndexOutOfBounds();

    uint256 private constant U16_PER_WORD = 16;

    function packFeeRates(uint16[] memory fees) internal pure returns (PackedFeeRates) {
        if (fees.length > U16_PER_WORD) revert FeeTiersExceedsMax();

        uint256 packedValue = 0;
        for (uint256 i; i < fees.length; i++) {
            packedValue = packedValue | (uint256(fees[i]) << (i * U16_PER_WORD));
        }

        return PackedFeeRates.wrap(packedValue);
    }

    function getFeeAt(PackedFeeRates fees, uint256 index) internal pure returns (uint16) {
        if (index >= 15) revert FeeTierIndexOutOfBounds();

        uint256 shiftBits = index * U16_PER_WORD;

        return uint16((PackedFeeRates.unwrap(fees) >> shiftBits) & 0xFFFF);
    }
}

enum FeeTiers {
    ZERO,
    ONE,
    TWO
}

struct FeeData {
    mapping(address token => uint256) totalFees;
    mapping(address token => uint256) unclaimedFees;
    mapping(address account => FeeTiers) accountFeeTier;
}

using FeeDataLib for FeeData global;

/// @custom:storage-location erc7201:FeeDataStorage
library FeeDataStorageLib {
    bytes32 constant FEE_DATA_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("FeeDataStorage")) - 1)) & ~bytes32(uint256(0xff));

    /// @dev Gets the storage slot of the FeeData struct
    // slither-disable-next-line uninitialized-storage
    function getFeeDataStorage() internal pure returns (FeeData storage self) {
        bytes32 position = FEE_DATA_STORAGE_POSITION;

        // slither-disable-next-line assembly
        assembly {
            self.slot := position
        }
    }
}

library FeeDataLib {
    using PackedFeeRatesLib for PackedFeeRates;
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address;

    /// @dev sig: 0x2227733fc4c8a9034cb58087dcf6995128b9c0233b038b03366aaf30c92b92d6
    event FeesClaimed(uint256 indexed eventNonce, address indexed token, uint256 fee);
    /// @dev sig: 0xfaa858b3dfeba08d811f5f70b037ea5cb20192ab57f696df5a74a281ef22751b
    event AccountFeeTierUpdated(uint256 indexed eventNonce, address indexed account, FeeTiers newTier);

    event FeesAccrued(uint256 indexed eventNonce, address indexed token, uint256 amount);

    uint256 constant FEE_SCALING = 10_000_000;

    /// @dev Returns the taker fee for a given amount and account
    function getTakerFee(FeeData storage self, PackedFeeRates takerRates, address account, uint256 amount)
        internal
        view
        returns (uint256)
    {
        if (amount == 0) return 0;

        uint16 feeRate = takerRates.getFeeAt(uint256(self.accountFeeTier[account]));
        return amount.fullMulDiv(feeRate, FEE_SCALING);
    }

    /// @dev Returns the maker fee for a given amount and account
    function getMakerFee(FeeData storage self, PackedFeeRates makerRates, address account, uint256 amount)
        internal
        view
        returns (uint256)
    {
        if (amount == 0) return 0;

        uint16 feeRate = makerRates.getFeeAt(uint256(self.accountFeeTier[account]));
        return amount.fullMulDiv(feeRate, FEE_SCALING);
    }

    /// @dev Returns the fee tier for a given account
    function getAccountFeeTier(FeeData storage self, address account) internal view returns (FeeTiers tier) {
        return self.accountFeeTier[account];
    }

    /// @dev Sets the fee tier for a given account
    function setAccountFeeTier(FeeData storage self, address account, FeeTiers feeTier) internal {
        self.accountFeeTier[account] = feeTier;

        emit AccountFeeTierUpdated(FeeDataEventNonce.inc(), account, feeTier);
    }

    /// @dev Accrues fees for a given token
    function accrueFee(FeeData storage self, address token, uint256 amount) internal {
        self.totalFees[token] += amount;
        self.unclaimedFees[token] += amount;

        emit FeesAccrued(FeeDataEventNonce.inc(), token, amount);
    }

    /// @dev Claims fees for a given token
    function claimFees(FeeData storage self, address token) internal returns (uint256 fees) {
        fees = self.unclaimedFees[token];
        delete self.unclaimedFees[token];

        emit FeesClaimed(FeeDataEventNonce.inc(), token, fees);
    }
}
