// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import {CLOBManager} from "../../../contracts/clob/CLOBManager.sol";
import {CLOB} from "../../../contracts/clob/CLOB.sol";

import {ICLOB} from "../../../contracts/clob/ICLOB.sol";
import {Side, Order} from "../../../contracts/clob/types/Order.sol";

import "forge-std/Script.sol";
import {TestPlus} from "../../../lib/solady/test/utils/TestPlus.sol";

contract CLOBAnvilFuzzTrader is Script, TestPlus {
    address[] accounts;

    CLOBManager clobManager;
    CLOB clob;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    constructor(address _clobManager, address _clob, address[] memory _accounts) {
        clobManager = CLOBManager(_clobManager);
        clob = CLOB(_clob);
        accounts = _accounts;
    }

    function setAccounts(address[] memory _accounts) external {
        accounts = _accounts;
    }

    /*//////////////////////////////////////////////////////////////
                               FUZZ TRADE
    //////////////////////////////////////////////////////////////*/

    address taker;
    address maker1;
    address maker2;
    address maker3;

    uint256 takerAmount;
    uint256 maker1Amount;
    uint256 maker2Amount;
    uint256 maker3Amount;

    uint256[] orderIds;

    function fuzzTrade(uint256, uint256 iterations, bool neverClearBook, bool clearBookAtEnd) public {
        _fuzzTrade(_random(), iterations, 0, false, neverClearBook, clearBookAtEnd);
    }

    function fuzzTrade(
        uint256,
        uint256 iterations,
        uint32 timestampRangeFromNow,
        bool neverClearBook,
        bool clearBookAtEnd
    ) public {
        _fuzzTrade(_random(), iterations, timestampRangeFromNow, false, neverClearBook, clearBookAtEnd);
    }

    function fuzzTradePostOnly(
        uint256,
        uint256 iterations,
        uint32 timestampRangeFromNow,
        bool postOnly,
        bool neverClearBook,
        bool clearBookAtEnd
    ) public {
        _fuzzTrade(_random(), iterations, timestampRangeFromNow, postOnly, neverClearBook, clearBookAtEnd);
    }

    function fuzzFillOrder(uint256, uint256 iterations, bool fillOrKill) public {
        _fuzzFillOrder(_random(), iterations, fillOrKill);
    }

    function fuzzAmendOrder(
        uint256,
        uint256 iterations,
        uint32 timestampRangeFromNow,
        bool reduceAmountOnly,
        bool changeAmount,
        bool changePrice,
        bool changeSide
    ) public {
        for (uint256 i; i < iterations; i++) {
            Order memory order = clob.getOrder(orderIds[i]);

            if (order.amount == 0) continue;

            uint256 newMaxAmount = reduceAmountOnly ? order.amount : order.amount * 2;
            order.price = changePrice ? _hem(_random(), 0, order.price) : order.price;
            order.amount = changeAmount ? _hem(_random(), 0, newMaxAmount) : order.amount;
            order.side = changeSide ? (_randomChance(2) ? Side.BUY : Side.SELL) : order.side;
            order.cancelTimestamp = uint32(_hem(_random(), block.timestamp, block.timestamp + timestampRangeFromNow));

            clob.amend(
                order.owner,
                ICLOB.AmendArgs({
                    orderId: orderIds[i],
                    amountInBase: order.amount,
                    price: order.price,
                    cancelTimestamp: order.cancelTimestamp,
                    side: order.side,
                    limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
                })
            );
        }
    }

    function clearBook() public {
        _clearBook();
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function _fuzzTrade(
        uint256,
        uint256 iterations,
        uint32 timestampRangeFromNow,
        bool postOnly,
        bool neverClearBook,
        bool clearBookAtEnd
    ) internal {

        for (uint256 i; i < iterations; i++) {
            _setupTraders();
            _setupAmounts();

            uint256 price = _getPrice();
            bool takerLong = _randomChance(2);

            orderIds.push(
                _placeLimitOrder(
                    maker1, maker1Amount, price, !takerLong, postOnly, timestampRangeFromNow
                )
            );
            orderIds.push(
                _placeLimitOrder(
                    maker2, maker2Amount, price, !takerLong, postOnly, timestampRangeFromNow
                )
            );
            orderIds.push(
                _placeLimitOrder(
                    maker3, maker3Amount, price, !takerLong, postOnly, timestampRangeFromNow
                )
            );

            uint256 orderId = _placeFillOrder(price, takerLong);
            orderIds.push(orderId);

            if (!neverClearBook && !clearBookAtEnd) _clearBook();
        }

        if (!neverClearBook && clearBookAtEnd) _clearBook();
    }

    function _fuzzFillOrder(uint256, uint256 iterations, bool immediateOrCancel) internal {
        for (uint256 i; i < iterations; i++) {
            _setupTraders();
            _setupAmounts();

            uint256 price = _getPrice();
            bool takerLong = _randomChance(2);

            _fillOrder(price, takerLong, immediateOrCancel);
        }
    }

    function _placeLimitOrder(
        address maker,
        uint256 amount,
        uint256 price,
        bool bid,
        bool postOnly,
        uint32 timestampRangeFromNow
    ) internal returns (uint256 orderId) {
        ICLOB.PostLimitOrderArgs memory makerArgs = ICLOB.PostLimitOrderArgs({
            amountInBase: amount,
            price: price,
            cancelTimestamp: uint32(_hem(_random(), block.timestamp, block.timestamp + timestampRangeFromNow)),
            side: bid ? Side.BUY : Side.SELL,
            clientOrderId: 0,
            limitOrderType: postOnly ? ICLOB.LimitOrderType.POST_ONLY : ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
        });

        return clob.postLimitOrder(maker, makerArgs).orderId;
    }

    function _placeFillOrder(uint256 price, bool long) internal returns (uint256 orderId) {
        if (_randomChance(2)) _fillOrder(price, long, true);
        else orderId = _limitOrder(price, long);
    }

    function _fillOrder(uint256 price, bool long, bool immediateOrCancel) internal {
        ICLOB.PostFillOrderArgs memory takerArgs = ICLOB.PostFillOrderArgs({
            amount: takerAmount,
            priceLimit: price,
            side: long ? Side.BUY : Side.SELL,
            amountIsBase: true,
            fillOrderType: immediateOrCancel ? ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL : ICLOB.FillOrderType.FILL_OR_KILL
        });

        clob.postFillOrder(taker, takerArgs);
    }

    function _limitOrder(uint256 price, bool long) internal returns (uint256 orderId) {
        ICLOB.PostLimitOrderArgs memory makerArgs = ICLOB.PostLimitOrderArgs({
            amountInBase: takerAmount,
            price: price,
            cancelTimestamp: 0,
            side: long ? Side.BUY : Side.SELL,
            clientOrderId: 0,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
        });

        return clob.postLimitOrder(taker, makerArgs).orderId;
    }

    function _clearBook() internal {
        for (uint256 i; i < orderIds.length; i++) {
            _cancelOrder(orderIds[i]);
        }
    }

    function _cancelOrder(uint256 orderId) internal {
        Order memory order = clob.getOrder(orderId);

        if (order.amount == 0) return;

        uint256[] memory _orderIds = new uint256[](1);
        _orderIds[0] = orderId;

        clob.cancel(order.owner, ICLOB.CancelArgs({orderIds: orderIds}));
    }

    function _setupTraders() internal {
        address[] memory traders = new address[](4);

        for (uint256 i; i < traders.length; ++i) {
            traders[i] = _getUniqueTrader(traders);
        }

        taker = traders[0];
        maker1 = traders[1];
        maker2 = traders[2];
        maker3 = traders[3];
    }

    function _setupAmounts() internal {
        maker1Amount = _hem(_random(), 1e18, 3e18);
        maker2Amount = _hem(_random(), 1e18, 3e18);
        maker3Amount = _hem(_random(), 1e18, 3e18);

        takerAmount = _hem(_random(), maker1Amount / 2, maker1Amount + maker2Amount + maker3Amount);
    }

    function _getUniqueTrader(address[] memory exclude) internal returns (address trader) {
        trader = accounts[_hem(_random(), 0, accounts.length - 1)];

        for (uint256 i; i < exclude.length; i++) {
            if (trader == exclude[i]) return _getUniqueTrader(exclude);
        }
    }

    function _getPrice() internal returns (uint256 price) {
        (uint256 bestBid, uint256 bestAsk) = clob.getTOB();
        uint256 tickSize = clob.getTickSize();

        price = _hem(_random(), bestBid - 50e18, bestAsk + 50e18);

        if (price % tickSize != 0) price -= price % tickSize;
    }
}
