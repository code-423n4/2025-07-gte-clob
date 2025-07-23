// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {TestPlus} from "lib/solady/test/utils/TestPlus.sol";
import {DynamicArrayLib} from "lib/solady/src/utils/DynamicArrayLib.sol";
import {Math} from "lib/openzeppelin-contracts/contracts/utils/math/Math.sol";

import {CLOBTestBase} from "test/clob/utils/CLOBTestBase.sol";

import {ICLOB} from "contracts/clob/ICLOB.sol";
import {CLOBManager} from "contracts/clob/CLOBManager.sol";
import {Side, Order, OrderId} from "contracts/clob/types/Order.sol";

contract CLOBViewsTest is CLOBTestBase, TestPlus {
    using DynamicArrayLib for uint256[];

    function testFuzz_getOrdersPaginatedPrice(uint256) public {
        uint256 orderAmount = _hem(_random(), 2, 20);
        uint256 pageSize = _hem(_random(), 1, 20);
        Side side = _randomChance(2) ? Side.BUY : Side.SELL;

        ICLOB[] memory markets = new ICLOB[](1);
        uint8[] memory maxLims = new uint8[](1);

        markets[0] = ICLOB(address(clob));
        maxLims[0] = uint8(orderAmount);

        clobManager.setMaxLimitsPerTx(markets, maxLims);

        uint256[] memory orderIds = _generateRandomOrders(orderAmount, orderAmount, side);

        (uint256 maxBid, uint256 minAsk) = clob.getTOB();
        uint256 startPrice = side == Side.BUY ? maxBid : minAsk;
        (Order[] memory orders, Order memory nextOrder) = clob.getOrdersPaginated(startPrice, side, pageSize);

        for (uint256 i = 0; i < orders.length; i++) {
            assertEq(orderIds.contains(orders[i].id.unwrap()), true);
        }

        for (uint256 i = 0; i < orders.length - 1; i++) {
            (side == Side.BUY)
                ? assertGe(orders[i].price, orders[i + 1].price)
                : assertLe(orders[i].price, orders[i + 1].price);
        }

        (pageSize >= orderAmount)
            ? assertEq(nextOrder.id.unwrap(), 0)
            : assertEq(orderIds.contains(nextOrder.id.unwrap()), true);

        assertEq(orders.length, Math.min(pageSize, orderAmount));
    }

    function testFuzz_getOrdersPaginatedOrderId(uint256) public {
        uint256 orderAmount = _hem(_random(), 2, 20);
        uint256 pageSize = _hem(_random(), 1, 20);
        Side side = _randomChance(2) ? Side.BUY : Side.SELL;

        ICLOB[] memory markets = new ICLOB[](1);
        uint8[] memory maxLims = new uint8[](1);

        markets[0] = ICLOB(address(clob));
        maxLims[0] = uint8(orderAmount);

        clobManager.setMaxLimitsPerTx(markets, maxLims);

        uint256[] memory orderIds = _generateRandomOrders(orderAmount, orderAmount, side);

        OrderId startOrderId = OrderId.wrap(orderIds[_hem(_random(), 0, orderIds.length - 1)]);
        (Order[] memory orders, Order memory nextOrder) = clob.getOrdersPaginated(startOrderId, pageSize);

        for (uint256 i = 0; i < orders.length; i++) {
            assertEq(orderIds.contains(orders[i].id.unwrap()), true);
        }

        for (uint256 i = 0; i < orders.length - 1; i++) {
            (side == Side.BUY)
                ? assertGe(orders[i].price, orders[i + 1].price)
                : assertLe(orders[i].price, orders[i + 1].price);
        }

        if (nextOrder.id.unwrap() != 0) assertEq(orderIds.contains(nextOrder.id.unwrap()), true);
    }

    function _generateOrder(address user, uint256 amountInBase, uint256 price, Side side)
        internal
        returns (uint256 result)
    {
        setupTokens(side, user, amountInBase, price, true);

        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price,
            cancelTimestamp: 0,
            side: side,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
        });

        vm.startPrank(user);
        result = clob.postLimitOrder(user, args).orderId;
        vm.stopPrank();
    }

    function _generateRandomOrders(uint256, uint256 numOrders, Side side) internal returns (uint256[] memory results) {
        results = new uint256[](numOrders);
        for (uint256 i = 0; i < numOrders; i++) {
            results[i] = _generateOrder(
                _randomNonZeroAddress(),
                _hem(_random(), clob.getMarketSettings().minLimitOrderAmountInBase, type(uint64).max),
                _hem(_random(), 1, 100) * clob.getMarketSettings().tickSize,
                side
            );
        }
    }
}
