// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ICLOB, MakerCredit} from "../clob/ICLOB.sol";
import {OperatorRoles} from "../utils/Operator.sol";
import {FeeTiers} from "../clob/types/FeeData.sol";

/**
 * @title IAccountManager
 * @notice Interface defining account management functions
 */
interface IAccountManager {

    // Getters
    function getAccountBalance(address account, address token) external view returns (uint256);
    function getEventNonce() external view returns (uint256);
    function getTotalFees(address token) external view returns (uint256);
    function getUnclaimedFees(address token) external view returns (uint256);
    function getFeeTier(address account) external view returns (FeeTiers);
    function getSpotTakerFeeRateForTier(FeeTiers tier) external view returns (uint256);
    function getSpotMakerFeeRateForTier(FeeTiers tier) external view returns (uint256);

    // Operator functions (inherited from Operator.sol)

    // Accounts
    function deposit(address account, address token, uint256 amount) external;
    function withdraw(address account, address token, uint256 amount) external;
    function depositFromRouter(address account, address token, uint256 amount) external;
    function withdrawToRouter(address account, address token, uint256 amount) external;

    // Admin called during market creation by CLOBManager
    function registerMarket(address market) external;

    // Settlement called by markets directly  
    function settleIncomingOrder(ICLOB.SettleParams calldata params) external returns (uint256 takerFee);
    
    // Fee collection and management
    function collectFees(address token, address feeRecipient) external returns (uint256 fee);
    function setSpotAccountFeeTier(address account, FeeTiers feeTier) external;
    function setSpotAccountFeeTiers(address[] calldata accounts, FeeTiers[] calldata feeTiers) external;

    // Direct market operations called by CLOB (market) contracts
    function creditAccount(address account, address token, uint256 amount) external;
    function creditAccountNoEvent(address account, address token, uint256 amount) external;
    function debitAccount(address account, address token, uint256 amount) external;
}