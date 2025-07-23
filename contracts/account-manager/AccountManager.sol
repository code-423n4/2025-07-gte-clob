// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {IAccountManager} from "./IAccountManager.sol";
import {ICLOB, MakerCredit} from "../clob/ICLOB.sol";
import {Side} from "../clob/types/Order.sol";
import {OperatorHelperLib} from "../utils/types/OperatorHelperLib.sol";
import {EventNonceLib as AccountEventNonce} from "../utils/types/EventNonce.sol";
import {Initializable} from "@solady/utils/Initializable.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {Operator, OperatorRoles} from "../utils/Operator.sol";
import {FeeData, FeeDataLib, FeeDataStorageLib, PackedFeeRates, PackedFeeRatesLib, FeeTiers} from "../clob/types/FeeData.sol";
import {Roles} from "../clob/types/Roles.sol";


struct AccountManagerStorage {
    mapping(address market => bool) isMarket;
    mapping(address account => mapping(address asset => uint256)) accountTokenBalances;
}

/**
 * @title AccountManager
 * @notice Handles account balances, deposits, withdrawals, for GTE spot as well as inheriting Operator
 */
contract AccountManager is IAccountManager, Operator, Initializable, OwnableRoles {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;
    using PackedFeeRatesLib for PackedFeeRates;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev sig: 0x07796b317344e6f18fa32ed89b6074ad66549cee7fb7b8c3e9f1c42c496f1c5c
    event MarketRegistered(uint256 indexed eventNonce, address indexed market);
    /// @dev sig: 0x1ae35cf838a52070167575d4dedf6631cc160136bee10eeca1575d2e3cc8a075
    event AccountDebited(uint256 indexed eventNonce, address indexed account, address indexed token, uint256 amount);
    /// @dev sig: 0x074f9f8975d437bea257b7e6abcfb4b45312683f7f8f120dde3faae76f783b58
    event AccountCredited(uint256 indexed eventNonce, address indexed account, address indexed token, uint256 amount);


    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev sig: 0x00b8f216
    error BalanceInsufficient();
    /// @dev sig: 0x467cb8b4
    error GTERouterUnauthorized();
    /// @dev sig: 0x30eee8ba
    error CLOBManagerUnauthorized();
    /// @dev sig: 0x9d1c9c18
    error MarketUnauthorized();
    /// @dev sig: 0x38422dcd
    error UnmatchingArrayLengths();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     IMMUTABLE STATE                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The global router address that can bypass the operator check
    address public immutable gteRouter;
    /// @dev The CLOBManager address that can call settlement functions
    address public immutable clobManager;
    /// @dev Packed spot maker fee rates for all tiers
    PackedFeeRates public immutable spotMakerFeeRates;
    /// @dev Packed spot taker fee rates for all tiers
    PackedFeeRates public immutable spotTakerFeeRates;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        MODIFIERS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Ensures msg.sender is a registered market
    modifier onlyMarket() {
        if (!_getAccountStorage().isMarket[msg.sender]) revert MarketUnauthorized();
        _;
    }

    /// @dev Ensures msg.sender is the router
    modifier onlyGTERouter() {
        if (msg.sender != gteRouter) revert GTERouterUnauthorized();
        _;
    }

    /// @dev Ensures msg.sender is the CLOBManager
    modifier onlyCLOBManager() {
        if (msg.sender != clobManager) revert CLOBManagerUnauthorized();
        _;
    }

    /// @dev Ensures that if an account is not the msg.sender, both that account and the owner have approved msg.sender
    modifier onlySenderOrOperator(address account, OperatorRoles requiredRole) {
        OperatorHelperLib.onlySenderOrOperator(_getOperatorStorage(), gteRouter, account, requiredRole);
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTRUCTOR                         */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor(
        address _gteRouter,
        address _clobManager,
        uint16[] memory _spotMakerFees,
        uint16[] memory _spotTakerFees
    ) {
        gteRouter = _gteRouter;
        clobManager = _clobManager;
        spotMakerFeeRates = PackedFeeRatesLib.packFeeRates(_spotMakerFees);
        spotTakerFeeRates = PackedFeeRatesLib.packFeeRates(_spotTakerFees);
        _disableInitializers();
    }

    /// @dev Initializes the contract
    function initialize(address _owner) external initializer {
        _initializeOwner(_owner);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    EXTERNAL GETTERS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Gets an `account`'s balance of `token`
    function getAccountBalance(address account, address token) external view returns (uint256) {
        return _getAccountStorage().accountTokenBalances[account][token];
    }

    /// @notice Gets the current event nonce
    function getEventNonce() external view returns (uint256) {
        return AccountEventNonce.getCurrentNonce();
    }

    /// @notice Gets the total fees collected for a token
    function getTotalFees(address token) external view returns (uint256) {
        return FeeDataStorageLib.getFeeDataStorage().totalFees[token];
    }

    /// @notice Gets the unclaimed fees for a token
    function getUnclaimedFees(address token) external view returns (uint256) {
        return FeeDataStorageLib.getFeeDataStorage().unclaimedFees[token];
    }

    /// @notice Gets the fee tier for an account
    function getFeeTier(address account) external view returns (FeeTiers) {
        return FeeDataStorageLib.getFeeDataStorage().getAccountFeeTier(account);
    }

    /// @notice Gets the spot taker fee rate for a given fee tier
    function getSpotTakerFeeRateForTier(FeeTiers tier) external view returns (uint256) {
        return spotTakerFeeRates.getFeeAt(uint256(tier));
    }

    /// @notice Gets the spot maker fee rate for a given fee tier
    function getSpotMakerFeeRateForTier(FeeTiers tier) external view returns (uint256) {
        return spotMakerFeeRates.getFeeAt(uint256(tier));
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         ACCOUNTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Deposits via transfer from the account
    function deposit(address account, address token, uint256 amount) external virtual onlySenderOrOperator(account, OperatorRoles.SPOT_DEPOSIT) {
        _creditAccount(_getAccountStorage(), account, token, amount);
        token.safeTransferFrom(account, address(this), amount);
    }

    /// @notice Deposits via transfer from the router
    function depositFromRouter(address account, address token, uint256 amount) external onlyGTERouter {
        _creditAccount(_getAccountStorage(), account, token, amount);
        token.safeTransferFrom(gteRouter, address(this), amount);
    }

    /// @notice Withdraws to account
    function withdraw(address account, address token, uint256 amount) external virtual onlySenderOrOperator(account, OperatorRoles.SPOT_WITHDRAW) {
        _debitAccount(_getAccountStorage(), account, token, amount);
        token.safeTransfer(account, amount);
    }

    /// @notice Withdraws from account to router
    function withdrawToRouter(address account, address token, uint256 amount) external onlyGTERouter {
        _debitAccount(_getAccountStorage(), account, token, amount);
        token.safeTransfer(gteRouter, amount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ADMIN                            */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Registers a market address, can only be called by CLOBManager
    function registerMarket(address market) external onlyCLOBManager {
        _getAccountStorage().isMarket[market] = true;
        emit MarketRegistered(AccountEventNonce.inc(), market);
    }

    /// @notice Collects accrued fees for a token and transfers to recipient
    function collectFees(address token, address feeRecipient) external virtual onlyOwnerOrRoles(Roles.FEE_COLLECTOR) returns (uint256 fee) {
        FeeData storage feeData = FeeDataStorageLib.getFeeDataStorage();
        fee = feeData.claimFees(token);

        if (fee > 0) {
            // Transfer fees directly from contract balance to recipient
            token.safeTransfer(feeRecipient, fee);
        }
    }

    /// @notice Sets the spot fee tier for a single account, can only be called by CLOBManager
    function setSpotAccountFeeTier(address account, FeeTiers feeTier) external virtual onlyCLOBManager {
        FeeData storage feeData = FeeDataStorageLib.getFeeDataStorage();
        feeData.setAccountFeeTier(account, feeTier);
    }

    /// @notice Sets the spot fee tiers for multiple accounts, can only be called by CLOBManager
    function setSpotAccountFeeTiers(address[] calldata accounts, FeeTiers[] calldata feeTiers) external virtual onlyCLOBManager {
        if (accounts.length != feeTiers.length) revert UnmatchingArrayLengths();

        FeeData storage feeData = FeeDataStorageLib.getFeeDataStorage();
        for (uint256 i = 0; i < accounts.length; i++) {
            feeData.setAccountFeeTier(accounts[i], feeTiers[i]);
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        SETTLEMENT                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice The hook for markets to perform account settlement after a fill, including fee calculations
    function settleIncomingOrder(ICLOB.SettleParams calldata params) external virtual onlyMarket returns (uint256 takerFee) {
        AccountManagerStorage storage self = _getAccountStorage();
        FeeData storage feeData = FeeDataStorageLib.getFeeDataStorage();

        // Credit taker less fee
        address takerFeeToken;
        if (params.side == Side.BUY) {
            takerFee = feeData.getTakerFee(spotTakerFeeRates, params.taker, params.takerBaseAmount);
            takerFeeToken = params.baseToken;

            // Taker settlement
            _debitAccount(self, params.taker, params.quoteToken, params.takerQuoteAmount);
            _creditAccount(self, params.taker, params.baseToken, params.takerBaseAmount - takerFee);
        } else {
            takerFee = feeData.getTakerFee(spotTakerFeeRates, params.taker, params.takerQuoteAmount);
            takerFeeToken = params.quoteToken;

            // Taker settlement
            _debitAccount(self, params.taker, params.baseToken, params.takerBaseAmount);
            _creditAccount(self, params.taker, params.quoteToken, params.takerQuoteAmount - takerFee);
        }

        // Accrue taker fee
        if (takerFee > 0) {
            feeData.accrueFee(takerFeeToken, takerFee);
        }

        // Process maker settlement and fees
        uint256 currMakerFee = 0;
        uint256 totalQuoteMakerFee = 0;
        uint256 totalBaseMakerFee = 0;

        for (uint256 i; i < params.makerCredits.length; ++i) {
            MakerCredit memory credit = params.makerCredits[i];

            // Calculate fees only for the matching side
            if (params.side == Side.BUY && credit.quoteAmount > 0) {
                currMakerFee = feeData.getMakerFee(spotMakerFeeRates, credit.maker, credit.quoteAmount);
                credit.quoteAmount -= currMakerFee;
                totalQuoteMakerFee += currMakerFee;
            } else if (params.side == Side.SELL && credit.baseAmount > 0) {
                currMakerFee = feeData.getMakerFee(spotMakerFeeRates, credit.maker, credit.baseAmount);
                credit.baseAmount -= currMakerFee;
                totalBaseMakerFee += currMakerFee;
            }

            // Credit both base and quote amounts if any (not just fills less fee, but also expiry and non-competitive refunds)
            if (credit.baseAmount > 0) {
                _creditAccountNoEvent(self, credit.maker, params.baseToken, credit.baseAmount);
            }

            if (credit.quoteAmount > 0) {
                _creditAccountNoEvent(self, credit.maker, params.quoteToken, credit.quoteAmount);
            }
        }

        // Accrue total collected maker fees
        if (totalBaseMakerFee > 0) {
            feeData.accrueFee(params.baseToken, totalBaseMakerFee);
        }
        if (totalQuoteMakerFee > 0) {
            feeData.accrueFee(params.quoteToken, totalQuoteMakerFee);
        }
    }

    /// @notice Credits account, called by markets for amends/cancels
    function creditAccount(address account, address token, uint256 amount) external virtual onlyMarket {
        _creditAccount(_getAccountStorage(), account, token, amount);
    }

    /// @notice Credits account without event, called by markets for non-competitive order removal
    function creditAccountNoEvent(address account, address token, uint256 amount) external virtual onlyMarket {
        _creditAccountNoEvent(_getAccountStorage(), account, token, amount);
    }

    /// @notice Debits account, called by markets for amends
    function debitAccount(address account, address token, uint256 amount) external virtual onlyMarket {
        _debitAccount(_getAccountStorage(), account, token, amount);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    INTERNAL HELPERS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _creditAccount(AccountManagerStorage storage self, address account, address token, uint256 amount) internal {
        unchecked {
            self.accountTokenBalances[account][token] += amount;
        }
        emit AccountCredited(AccountEventNonce.inc(), account, token, amount);
    }

    function _creditAccountNoEvent(AccountManagerStorage storage self, address account, address token, uint256 amount) internal {
        unchecked {
            self.accountTokenBalances[account][token] += amount;
        }
    }

    function _debitAccount(AccountManagerStorage storage self, address account, address token, uint256 amount) internal {
        if (self.accountTokenBalances[account][token] < amount) revert BalanceInsufficient();

        unchecked {
            self.accountTokenBalances[account][token] -= amount;
        }
        emit AccountDebited(AccountEventNonce.inc(), account, token, amount);
    }

    /// @dev Helper to set the storage slot of the storage struct for this contract
    function _getAccountStorage() internal pure returns (AccountManagerStorage storage ds) {
        return AccountManagerStorageLib.getAccountManagerStorage();
    }
}

using AccountManagerStorageLib for AccountManagerStorage global;

/// @custom:storage-location erc7201:AccountManagerStorage
library AccountManagerStorageLib {
    bytes32 constant ACCOUNT_MANAGER_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("AccountManagerStorage")) - 1)) & ~bytes32(uint256(0xff));

    /// @dev Gets the storage slot of the storage struct for the contract calling this library function
    // slither-disable-next-line uninitialized-storage
    function getAccountManagerStorage() internal pure returns (AccountManagerStorage storage self) {
        bytes32 position = ACCOUNT_MANAGER_STORAGE_POSITION;

        // slither-disable-next-line assembly
        assembly {
            self.slot := position
        }
    }
}