// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ICLOBManager} from "../ICLOBManager.sol";

import {RedBlackTree} from "./RedBlackTree.sol";
import {Side, Order, OrderLib, OrderId, OrderIdLib} from "./Order.sol";

import {EventNonceLib as BookEventNonce} from "contracts/utils/types/EventNonce.sol";

uint256 constant MIN_LIMIT_PRICE_IN_TICKS = 1;
uint256 constant MIN_MIN_LIMIT_ORDER_AMOUNT_BASE = 100;

struct Limit {
    uint64 numOrders;
    OrderId headOrder;
    OrderId tailOrder;
}

struct Book {
    RedBlackTree bidTree;
    RedBlackTree askTree;
    mapping(OrderId => Order) orders;
    mapping(uint256 price => Limit) bidLimits;
    mapping(uint256 price => Limit) askLimits;
}

struct MarketConfig {
    address quoteToken;
    address baseToken;
    uint256 quoteSize;
    uint256 baseSize;
}

struct MarketSettings {
    bool status;
    uint8 maxLimitsPerTx;
    uint256 minLimitOrderAmountInBase;
    uint256 tickSize;
    uint256 lotSizeInBase;
}

struct MarketMetadata {
    uint96 orderIdCounter;
    uint256 numBids;
    uint256 numAsks;
    uint256 baseTokenOpenInterest;
    uint256 quoteTokenOpenInterest;
}

using BookLib for Book global;
using CLOBStorageLib for Book global;

// slither-disable-start unimplemented-functions
library BookLib {
    using OrderIdLib for uint256;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev sig: 0xe4f5b5cce490cd2969d01f4e8d15a7ec5650b813f83bc427e602c826540052be
    event LimitOrderCreated(
        uint256 indexed eventNonce, OrderId indexed orderId, uint256 price, uint256 amount, Side side
    );

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev sig: 0xb3a23067
    error OrderIdInUse();
    /// @dev sig: 0x78591828
    error LotSizeInvalid();
    /// @dev sig: 0x9d6417b2
    error LimitPriceInvalid();
    /// @dev sig: 0x40dd76ff
    error LimitsPlacedExceedsMax();
    /// @dev sig: 0x2090fe47
    error LimitOrderAmountInvalid();

    /// @dev This caches the global max limit whitelist status stored in the manager
    /// so that makers placing a large number of limits only incurs one call to the factory
    /// intentionally not cleared
    bytes32 constant TRANSIENT_MAX_LIMIT_ALLOWLIST =
        keccak256(abi.encode(uint256(keccak256("TRANSIENT_MAX_LIMIT_ALLOWLIST")) - 1)) & ~bytes32(uint256(0xff));

    /// @dev This is the counter for how many limits have been placed in a txn, intentionally not cleared
    bytes32 constant TRANSIENT_LIMITS_PLACED =
        keccak256(abi.encode(uint256(keccak256("TRANSIENT_LIMITS_PLACED")) - 1)) & ~bytes32(uint256(0xff));

    // ASSERTIONS //

    /// @dev Asserts that the limit price is a multiple of the tick size
    function assertLimitPriceInBounds(Book storage self, uint256 price) internal view {
        uint256 tickSize = self.settings().tickSize;

        if (price % tickSize > 0 || price == 0) revert LimitPriceInvalid();
    }

    /// @dev Asserts that the limit order amount is greater than the min limit order amount in base
    function assertLimitOrderAmountInBounds(Book storage self, uint256 orderAmountInBase) internal view {
        if (orderAmountInBase < self.settings().minLimitOrderAmountInBase) revert LimitOrderAmountInvalid();
    }

    /// @dev Asserts that the limit order amount is a multiple of the lot size in base
    function assertLotSizeCompliant(Book storage self, uint256 orderAmountInBase) internal view {
        if (orderAmountInBase % self.settings().lotSizeInBase != 0) revert LotSizeInvalid();
    }

    /// @dev Asserts that the order id is not in use
    function assertUnusedOrderId(Book storage self, uint256 orderId) internal view {
        if (self.orders[orderId.toOrderId()].owner > address(0)) revert OrderIdInUse();
    }

    // MUTABLE FUNCTIONS //

    /// @dev Stores if the caller can avoid the max limit whitelist locally
    function setMaxLimitExemptTransient(address who, bool toggle) internal {
        bytes32 slot = keccak256(abi.encode(who, TRANSIENT_MAX_LIMIT_ALLOWLIST));

        // slither-disable-next-line assembly
        assembly {
            tstore(slot, toggle)
        }
    }

    /// @dev Increments the number of limits placed this txn, reverts if max is exceeded and caller is now allowlisted
    function incrementLimitsPlaced(Book storage self, address factory, address account) internal {
        uint8 limitsPlaced = getTransientLimitsPlaced();

        if (limitsPlaced >= self.settings().maxLimitsPerTx && !isMaxLimitExempt(self, factory, account)) {
            revert LimitsPlacedExceedsMax();
        }

        bytes32 slot = TRANSIENT_LIMITS_PLACED;

        // slither-disable-next-line assembly
        assembly {
            tstore(slot, add(limitsPlaced, 1))
        }
    }

    /// @dev Creates and returns a new OrderId nonce
    function incrementOrderId(Book storage self) internal returns (uint256) {
        return OrderIdLib.getOrderId(address(0), ++self.metadata().orderIdCounter);
    }

    /// @dev Adds a limit order to the book
    function addOrderToBook(Book storage self, Order memory order) internal {
        Limit storage limit = _updateBookPostOrder(self, order);

        _updateLimitPostOrder(self, limit, order);
    }

    /// @dev Removes an order from the book
    function removeOrderFromBook(Book storage self, Order storage order) internal {
        _updateLimitRemoveOrder(self, order);
        _updateBookRemoveOrder(self, order);
    }

    // VIEW FUNCTIONS //

    /// @dev Returns the max limit exempt status for an `account` (whether he's restricted to an amount of tx/block or not)
    function isMaxLimitExempt(Book storage self, address factory, address who) internal returns (bool allowed) {
        bytes32 slot = keccak256(abi.encode(who, TRANSIENT_MAX_LIMIT_ALLOWLIST));

        // slither-disable-next-line assembly
        assembly {
            allowed := tload(slot)
        }

        if (!allowed) {
            allowed = ICLOBManager(factory).getMaxLimitExempt(who);
            if (!allowed) return allowed;
            setMaxLimitExemptTransient(who, allowed);
            return allowed;
        }
    }

    /// @dev Returns the next orders for a given start order id and number of orders
    function getNextOrders(Book storage self, OrderId startOrderId, uint256 numOrders)
        internal
        view
        returns (Order[] memory orders)
    {
        Order storage currentOrder = self.orders[startOrderId];
        currentOrder.assertExists();

        uint256 count = 0;
        orders = new Order[](numOrders);

        while (count < numOrders && !currentOrder.isNull()) {
            orders[count] = currentOrder;
            count++;

            if (currentOrder.nextOrderId.unwrap() != 0) {
                currentOrder = self.orders[currentOrder.nextOrderId];
            } else {
                uint256 price = self.getNextBiggestPrice(currentOrder.price, currentOrder.side);

                if (price == 0) break;

                Limit storage nextLimit = self.getLimit(price, currentOrder.side);

                currentOrder = self.orders[nextLimit.headOrder];
            }
        }
    }

    function getOrdersPaginated(Book storage ds, Order memory startOrder, uint256 pageSize)
        internal
        view
        returns (Order[] memory result, Order memory nextOrder)
    {
        Order[] memory orders = new Order[](pageSize);
        nextOrder = startOrder;
        uint256 counter;

        while (counter < pageSize) {
            if (nextOrder.id.unwrap() == 0) break;
            orders[counter] = nextOrder;
            if (nextOrder.nextOrderId.unwrap() == 0) {
                nextOrder = nextOrder.side == Side.BUY
                    ? ds.orders[ds.bidLimits[ds.getNextSmallestPrice(nextOrder.price, Side.BUY)].headOrder]
                    : ds.orders[ds.askLimits[ds.getNextBiggestPrice(nextOrder.price, Side.SELL)].headOrder];
            } else {
                nextOrder = ds.orders[nextOrder.nextOrderId];
            }
            counter++;
        }

        assembly {
            result := orders
            mstore(mul(lt(counter, mload(result)), result), counter)
        }

        return (result, nextOrder);
    }

    // PURE FUNCTIONS //

    /// @dev Returns the number of limit orders placed this transation
    function getTransientLimitsPlaced() internal view returns (uint8 limitsPlaced) {
        bytes32 slot = TRANSIENT_LIMITS_PLACED;

        // This solidity version does not support the `transient` identifier
        // slither-disable-next-line assembly
        assembly {
            limitsPlaced := tload(slot)
        }
    }

    // PRIVATE FUNCTIONS //

    function _updateBookPostOrder(Book storage self, Order memory order) private returns (Limit storage limit) {
        if (order.side == Side.BUY) {
            limit = self.bidLimits[order.price];
            if (limit.numOrders == 0) self.bidTree.insert(order.price);
            self.metadata().numBids++;
            self.metadata().quoteTokenOpenInterest += self.getQuoteTokenAmount(order.price, order.amount);
        } else {
            limit = self.askLimits[order.price];
            if (limit.numOrders == 0) self.askTree.insert(order.price);
            self.metadata().numAsks++;
            self.metadata().baseTokenOpenInterest += order.amount;
        }

        self.orders[order.id] = order;
    }

    function _updateLimitPostOrder(Book storage self, Limit storage limit, Order memory order) private {
        limit.numOrders++;

        if (limit.headOrder.isNull()) {
            limit.headOrder = order.id;
            limit.tailOrder = order.id;
        } else {
            Order storage tailOrder = self.orders[limit.tailOrder];
            tailOrder.nextOrderId = order.id;
            order.prevOrderId = tailOrder.id;
            limit.tailOrder = order.id;
        }

        emit LimitOrderCreated(BookEventNonce.inc(), order.id, order.price, order.amount, order.side);
    }

    function _updateBookRemoveOrder(Book storage self, Order storage order) private {
        if (order.side == Side.BUY) {
            self.metadata().numBids--;

            self.metadata().quoteTokenOpenInterest -= self.getQuoteTokenAmount(order.price, order.amount);
        } else {
            self.metadata().numAsks--;

            self.metadata().baseTokenOpenInterest -= order.amount;
        }

        delete self.orders[order.id];
    }

    function _updateLimitRemoveOrder(Book storage self, Order storage order) private {
        uint256 price = order.price;

        Limit storage limit = order.side == Side.BUY ? self.bidLimits[price] : self.askLimits[price];

        if (limit.numOrders == 1) {
            if (order.side == Side.BUY) {
                delete self.bidLimits[price];
                self.bidTree.remove(price);
            } else {
                delete self.askLimits[price];
                self.askTree.remove(price);
            }
            return;
        }

        limit.numOrders--;

        OrderId prev = order.prevOrderId;
        OrderId next = order.nextOrderId;

        if (!prev.isNull()) self.orders[prev].nextOrderId = next;
        else limit.headOrder = next;

        if (!next.isNull()) self.orders[next].prevOrderId = prev;
        else limit.tailOrder = prev;
    }
}

/// @custom:storage-location erc7201:CLOBStorage
library CLOBStorageLib {
    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev sig: 0xdf07ebd269c613b8a3f2d3a9b3763bfed22597dc93ca6f40caf8773ebabf7d50
    event TickSizeUpdated(uint256 indexed eventNonce, uint256 indexed newTickSize);
    /// @dev sig: 0x1c8841f14ca7c4f639d9207829e05ea911febfd6609afc496f63efb5819f51f0
    event LotSizeInBaseUpdated(uint256 indexed eventNonce, uint256 indexed newLotSizeInBase);
    /// @dev sig: 0x1f4e491a4e8eba2c859a70417419f56aa296c496af7e1eccd17c5f2ee93aa36b
    event MaxLimitOrdersPerTxUpdated(uint256 indexed eventNonce, uint256 indexed newMaxLimits);
    /// @dev sig: 0xba6e3f8f80a920a3d4235f1df6df25a19c03bc81803cc4791feaee0aa6e548d3
    event MinLimitOrderAmountInBaseUpdated(uint256 indexed eventNonce, uint256 indexed newMinLimitOrderAmountInBase);

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev sig: 0x2cd8344a
    error NewLotSizeInvalid();
    /// @dev sig: 0xd35bd829
    error NewTickSizeInvalid();
    /// @dev sig: 0xd78d4cbe
    error NewMaxLimitsPerTxInvalid();
    /// @dev sig: 0x4e63c1c2
    error NewMinLimitOrderAmountInvalid();

    bytes32 constant CLOB_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("CLOBStorage")) - 1)) & ~bytes32(uint256(0xff));

    bytes32 constant MARKET_CONFIG_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("MarketConfigStorage")) - 1)) & ~bytes32(uint256(0xff));

    bytes32 constant MARKET_SETTINGS_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("MarketSettingsStorage")) - 1)) & ~bytes32(uint256(0xff));

    bytes32 constant MARKET_METADATA_STORAGE_POSITION =
        keccak256(abi.encode(uint256(keccak256("MarketMetadataStorage")) - 1)) & ~bytes32(uint256(0xff));

    /// @dev These functions expose the 3 book data structs as phantom fields
    /// while allowing their storage to be independant in case of updates

    function settings(Book storage) internal pure returns (MarketSettings storage) {
        return _getMarketSettingsStorage();
    }

    function config(Book storage) internal pure returns (MarketConfig storage) {
        return _getMarketConfigStorage();
    }

    function metadata(Book storage) internal pure returns (MarketMetadata storage) {
        return _getMarketMetadataStorage();
    }

    // slither-disable-next-line uninitialized-storage
    function _getCLOBStorage() internal pure returns (Book storage self) {
        bytes32 slot = CLOB_STORAGE_POSITION;

        // slither-disable-next-line assembly
        assembly {
            self.slot := slot
        }
    }

    // slither-disable-next-line uninitialized-storage
    function _getMarketConfigStorage() internal pure returns (MarketConfig storage self) {
        bytes32 slot = MARKET_CONFIG_STORAGE_POSITION;

        // slither-disable-next-line assembly
        assembly {
            self.slot := slot
        }
    }

    // slither-disable-next-line uninitialized-storage
    function _getMarketSettingsStorage() internal pure returns (MarketSettings storage self) {
        bytes32 slot = MARKET_SETTINGS_STORAGE_POSITION;

        // slither-disable-next-line assembly
        assembly {
            self.slot := slot
        }
    }

    // slither-disable-next-line uninitialized-storage
    function _getMarketMetadataStorage() internal pure returns (MarketMetadata storage self) {
        bytes32 slot = MARKET_METADATA_STORAGE_POSITION;

        // slither-disable-next-line assembly
        assembly {
            self.slot := slot
        }
    }

    /// @dev Returns the highest bid price
    function getBestBidPrice(Book storage self) internal view returns (uint256) {
        return self.bidTree.maximum();
    }

    /// @dev Returns the lowest ask price
    function getBestAskPrice(Book storage self) internal view returns (uint256) {
        return self.askTree.minimum();
    }

    /// @dev Returns the lowest bid price
    function getWorstBidPrice(Book storage self) internal view returns (uint256) {
        return self.bidTree.minimum();
    }

    /// @dev Returns the highest ask price
    function getWorstAskPrice(Book storage self) internal view returns (uint256) {
        return self.askTree.maximum();
    }

    /// @dev Returns the limit for a given price and side
    function getLimit(Book storage self, uint256 price, Side side) internal view returns (Limit storage) {
        return side == Side.BUY ? self.bidLimits[price] : self.askLimits[price];
    }

    /// @dev Returns the next biggest price for a given price and side
    function getNextBiggestPrice(Book storage self, uint256 price, Side side) internal view returns (uint256) {
        return side == Side.BUY ? self.bidTree.getNextBiggest(price) : self.askTree.getNextBiggest(price);
    }

    /// @dev Returns the next smallest price for a given price and side
    function getNextSmallestPrice(Book storage self, uint256 price, Side side) internal view returns (uint256) {
        return side == Side.BUY ? self.bidTree.getNextSmallest(price) : self.askTree.getNextSmallest(price);
    }

    /// @dev Returns the base token amount for a given price and quote amount
    function getBaseTokenAmount(Book storage self, uint256 price, uint256 quoteAmount)
        internal
        view
        returns (uint256)
    {
        return quoteAmount * self.config().baseSize / price;
    }

    /// @dev Returns the quote token amount for a given price and base amount
    function getQuoteTokenAmount(Book storage self, uint256 price, uint256 baseAmount)
        internal
        view
        returns (uint256 quoteAmount)
    {
        return baseAmount * price / self.config().baseSize;
    }

    function setMaxLimitsPerTx(Book storage self, uint8 newMaxLimits) internal {
        if (newMaxLimits == 0) revert NewMaxLimitsPerTxInvalid();

        self.settings().maxLimitsPerTx = newMaxLimits;

        emit MaxLimitOrdersPerTxUpdated(BookEventNonce.inc(), newMaxLimits);
    }

    function setTickSize(Book storage self, uint256 newTickSize) internal {
        if (newTickSize < MIN_LIMIT_PRICE_IN_TICKS) revert NewTickSizeInvalid();
        self.settings().tickSize = newTickSize;

        emit TickSizeUpdated(BookEventNonce.inc(), newTickSize);
    }

    function setMinLimitOrderAmountInBase(Book storage self, uint256 newMinLimitOrderAmountInBase) internal {
        if (newMinLimitOrderAmountInBase < MIN_MIN_LIMIT_ORDER_AMOUNT_BASE) revert NewMinLimitOrderAmountInvalid();

        self.settings().minLimitOrderAmountInBase = newMinLimitOrderAmountInBase;

        emit MinLimitOrderAmountInBaseUpdated(BookEventNonce.inc(), newMinLimitOrderAmountInBase);
    }

    function setLotSizeInBase(Book storage self, uint256 newLotSizeInBase) internal {
        if (newLotSizeInBase == 0) revert NewLotSizeInvalid();

        self.settings().lotSizeInBase = newLotSizeInBase;
        emit LotSizeInBaseUpdated(BookEventNonce.inc(), newLotSizeInBase);
    }

    /// @dev Initializes the market config and setting
    function init(Book storage self, MarketConfig memory marketConfig, MarketSettings memory marketSettings) internal {
        MarketConfig storage cs = self.config();
        MarketSettings storage ss = self.settings();

        cs.quoteToken = marketConfig.quoteToken;
        cs.baseToken = marketConfig.baseToken;
        cs.quoteSize = marketConfig.quoteSize;
        cs.baseSize = marketConfig.baseSize;

        ss.status = marketSettings.status;
        ss.maxLimitsPerTx = marketSettings.maxLimitsPerTx;
        ss.minLimitOrderAmountInBase = marketSettings.minLimitOrderAmountInBase;
        ss.tickSize = marketSettings.tickSize;
        ss.lotSizeInBase = marketSettings.lotSizeInBase;
    }
}
// slither-disable-end unimplemented-functions
