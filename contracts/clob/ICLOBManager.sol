// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IAccountManager} from "../account-manager/IAccountManager.sol";
import {FeeTiers} from "./types/FeeData.sol";
import {ICLOB} from "./ICLOB.sol";
import {Side} from "./types/Order.sol";
import {MakerCredit} from "./types/TransientMakerData.sol";

struct ConfigParams {
    address quoteToken;
    address baseToken;
    uint256 quoteSize;
    uint256 baseSize;
}

struct SettingsParams {
    address owner;
    uint8 maxLimitsPerTx;
    uint256 minLimitOrderAmountInBase;
    uint256 tickSize;
    uint256 lotSizeInBase;
}

interface ICLOBManager {
    // Basic getters from ICLOBAdminPanel
    function beacon() external view returns (address);
    function getMarketAddress(address quoteToken, address baseToken) external view returns (address);
    function isMarket(address market) external view returns (bool);

    // Market creation and management from ICLOBAdminPanel
    function createMarket(address baseToken, address quoteToken, SettingsParams calldata settings)
        external
        returns (address marketAddress);

    function setMaxLimitsPerTx(ICLOB[] calldata clobs, uint8[] calldata maxLimits) external;
    function setTickSizes(ICLOB[] calldata clobs, uint256[] calldata tickSizes) external;
    function setMinLimitOrderAmounts(ICLOB[] calldata clobs, uint256[] calldata minLimitOrderAmounts) external;

    // Limit management getters
    function getMaxLimitExempt(address account) external view returns (bool);

    // Fee and limit management
    function setAccountFeeTiers(address[] calldata accounts, FeeTiers[] calldata feeTiers) external;
    function setMaxLimitsExempt(address[] calldata accounts, bool[] calldata toggles) external;
}
