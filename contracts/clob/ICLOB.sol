// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Side, Order, OrderId} from "./types/Order.sol";
import {MarketConfig, MarketSettings, Limit} from "./types/Book.sol";
import {MakerCredit} from "./types/TransientMakerData.sol";
import {ICLOBManager} from "./ICLOBManager.sol";

interface ICLOB {
    struct SettleParams {
        Side side;
        address taker;
        uint256 takerBaseAmount;
        uint256 takerQuoteAmount;
        address baseToken;
        address quoteToken;
        MakerCredit[] makerCredits;
    }

    enum LimitOrderType {
        GOOD_TILL_CANCELLED,
        POST_ONLY
    }

    enum FillOrderType {
        FILL_OR_KILL,
        IMMEDIATE_OR_CANCEL
    }

    enum CancelType {
        USER,
        EXPIRY,
        NON_COMPETITIVE
    }

    struct PostLimitOrderArgs {
        uint256 amountInBase;
        uint256 price;
        uint32 cancelTimestamp; // unix timestamp after which the order is cancelled. Ignore if 0
        Side side;
        uint96 clientOrderId; // custom order id — id will be uint256(abi.encodePacked(account, clientOrderId))
        LimitOrderType limitOrderType;
    }

    struct PostLimitOrderResult {
        address account;
        uint256 orderId;
        uint256 amountPostedInBase; // amount posted in baseLots
        int256 quoteTokenAmountTraded; // negative if outgoing, positive if incoming
        int256 baseTokenAmountTraded; // negative if outgoing, positive if incoming
        uint256 takerFee;
    }

    struct PostFillOrderArgs {
        uint256 amount;
        uint256 priceLimit;
        Side side;
        bool amountIsBase;
        FillOrderType fillOrderType;
    }

    struct PostFillOrderResult {
        address account;
        uint256 orderId;
        int256 quoteTokenAmountTraded; // negative if outgoing, positive if incoming
        int256 baseTokenAmountTraded; // negative if outgoing, positive if incoming
        uint256 takerFee;
    }

    struct AmendArgs {
        uint256 orderId;
        uint256 amountInBase;
        uint256 price;
        uint32 cancelTimestamp;
        Side side;
        LimitOrderType limitOrderType;
    }

    struct CancelArgs {
        uint256[] orderIds;
    }

    // Post
    function postLimitOrder(address account, PostLimitOrderArgs memory args)
        external
        returns (PostLimitOrderResult memory);

    function postFillOrder(address account, PostFillOrderArgs memory args)
        external
        returns (PostFillOrderResult memory);

    function amend(address account, AmendArgs memory args) external returns (int256 quoteDelta, int256 baseDelta);

    function cancel(address account, CancelArgs memory args) external returns (uint256, uint256); // quoteToken refunded, baseToken refunded

    // Token Amount Calculators
    function getQuoteTokenAmount(uint256 price, uint256 amountInBaseLots) external view returns (uint256);

    function getBaseTokenAmount(uint256 price, uint256 amountInBaseLots) external view returns (uint256);

    // Getters

    function gteRouter() external view returns (address);

    function getQuoteToken() external view returns (address);

    function getBaseToken() external view returns (address);

    function getMarketConfig() external view returns (MarketConfig memory);

    function getTickSize() external view returns (uint256);

    function getOpenInterest() external view returns (uint256, uint256);

    function getOrder(uint256 orderId) external view returns (Order memory);

    function getTOB() external view returns (uint256, uint256);

    function getLimit(uint256 price, Side side) external view returns (Limit memory);

    function getNumBids() external view returns (uint256);

    function getNumAsks() external view returns (uint256);

    function getNextBiggestPrice(uint256 price, Side side) external view returns (uint256);

    function getNextSmallestPrice(uint256 price, Side side) external view returns (uint256);

    function getNextOrders(uint256 startOrderId, uint256 numOrders) external view returns (Order[] memory);

    function getNextOrderId() external view returns (uint256);

    function factory() external view returns (ICLOBManager);

    function getOrdersPaginated(uint256 startPrice, Side side, uint256 pageSize)
        external
        view
        returns (Order[] memory result, Order memory nextOrder);

    function getOrdersPaginated(OrderId startOrderId, uint256 pageSize)
        external
        view
        returns (Order[] memory result, Order memory nextOrder);

    function setMaxLimitsPerTx(uint8 newMaxLimits) external;
    function setTickSize(uint256 newTickSize) external;
    function setMinLimitOrderAmountInBase(uint256 newMinLimitOrderAmountInBase) external;
}
