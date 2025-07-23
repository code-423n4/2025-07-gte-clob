// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {CLOB, Order, OrderId, Limit, ICLOB, Side} from "contracts/clob/CLOB.sol";
import {CLOBTestBase, FixedPointMathLib} from "test/clob/utils/CLOBTestBase.sol";
import {MarketConfig} from "contracts/clob/types/Book.sol";
/**
 * Cases:
 *
 * Happy paths:
 * - quote refunded > 0 account (done)
 * - quote refunded > 0 instant (done)
 * - base refunded > 0 account (done)
 * - base refunded > 0, 0settlement instant (done)
 * - cancel filled order, cancel failed emitted (done)
 * - cancel partial filled order, only partial refund
 * - expired order is cancelled (done)
 *
 * Sad paths:
 * - orderId is null (doesnt revet, emaits failure) (done)
 * - order is owned by someone else (done)
 * - order is expired (done)
 *
 * Invariants:
 * - Open interest only changes by cancel amount in atoms (done)
 * - Order slot is fully clear after cacnel (done)
 * - limit, and orders in limit, are fully clear of cancelled order (done)
 * - Cancel event emitted propertly (done)
 */
contract CLOBCancelTest is CLOBTestBase {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address;

    struct CancelState {
        Order order;
        uint256 limitNumOrders;
        uint256 openInterest;
        uint256 ordersPerSide;
    }


    // HAPPY PATHS //
    // Orders that are expired can still be cancelled by the user isntead of cancelled during fill
    function test_cancel_expired_order() public {
        address maker = users[0];
        uint256 amountInBase = 2 ether;
        uint256 price = 10 ether;
        setupOrderExpiry = uint32(block.timestamp + 1);

        setupOrder(Side.BUY, maker, amountInBase, price);
        vm.warp(setupOrderExpiry + 1);

        uint256[] memory orderIds = new uint256[](1);
        orderIds[0] = 1;

        ICLOB.CancelArgs memory cancelArgs = ICLOB.CancelArgs({orderIds: orderIds});
        vm.expectEmit();
        emit OrderCanceled(4, 1, maker, quoteTokenAmount(price, amountInBase), 0, ICLOB.CancelType.USER);

        vm.prank(maker);
        clob.cancel(maker, cancelArgs);
    }

    // Cancel failed should be emitted if a cancel request was filled
    function test_cancel_filled_order() public {
        address maker = users[0];
        address taker = users[1];
        uint256 amountInBase = 2 ether;
        uint256 price = 10 ether;
        uint256 quoteAmount = quoteTokenAmount(price, amountInBase);

        setupOrder(Side.BUY, maker, amountInBase, price);
        setupTokens(Side.SELL, taker, quoteAmount, price, false);

        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: quoteAmount,
            priceLimit: price,
            side: Side.SELL,
            amountIsBase: false,
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        vm.prank(taker);
        clob.postFillOrder(taker, fillArgs);

        uint256[] memory orderIds = new uint256[](1);
        orderIds[0] = 1;

        ICLOB.CancelArgs memory cancelArgs = ICLOB.CancelArgs({orderIds: orderIds});

        vm.expectEmit();
        emit CLOB.CancelFailed(clob.getEventNonce() + 1, 1, maker);

        vm.prank(maker);
        clob.cancel(maker, cancelArgs);
    }

    function test_cancel_base_account() public {
        address user = users[1];
        uint256 amountInBase = 2 ether;
        uint256 price = 10 ether;

        // Deposit sufficient base tokens
        uint256 baseAmountToDeposit = setupTokens(Side.SELL, user, amountInBase, price, true);

        // Prepare arguments
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            clientOrderId: 0,
            amountInBase: amountInBase,
            price: price,
            cancelTimestamp: TOMORROW,
            side: Side.SELL,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED

        });

        vm.startPrank(user);

        // Post limit order
        ICLOB.PostLimitOrderResult memory result = clob.postLimitOrder(user, args);

        CancelState memory state = getPreCancelState(result.orderId);

        uint256[] memory orderIds = new uint256[](1);
        orderIds[0] = result.orderId;

        ICLOB.CancelArgs memory cArgs = ICLOB.CancelArgs({orderIds: orderIds});
        (, uint256 baseRefund) = clob.cancel(user, cArgs);

        assertPostCancelState(state);
        assertEq(clobManager.accountManager().getAccountBalance(user, address(baseToken)), baseAmountToDeposit);
        assertEq(baseRefund, baseAmountToDeposit);
    }
    function test_cancel_quote_account() public {
        address user = users[0];
        uint256 amountInBase = 2 ether;
        uint256 price = 10 ether;

        // Deposit sufficient quote tokens
        uint256 quoteAmountToDeposit = setupTokens(Side.BUY, user, amountInBase, price, true);

        // Prepare arguments
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            clientOrderId: 0,
            amountInBase: amountInBase,
            price: price,
            cancelTimestamp: TOMORROW,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED

        });

        vm.startPrank(user);
        // Post limit order and get state
        ICLOB.PostLimitOrderResult memory result = clob.postLimitOrder(user, args);

        CancelState memory state = getPreCancelState(result.orderId);

        uint256[] memory orderIds = new uint256[](1);
        orderIds[0] = result.orderId;

        ICLOB.CancelArgs memory cArgs = ICLOB.CancelArgs({orderIds: orderIds});
        (uint256 quoteRefund,) = clob.cancel(user, cArgs);

        assertPostCancelState(state);
        assertEq(clobManager.accountManager().getAccountBalance(user, address(quoteToken)), quoteAmountToDeposit);
        assertEq(quoteRefund, quoteAmountToDeposit);
    }
    function test_cancel_multiple_orders() public {
        address user = users[0];
        uint256 amountInBase = 10 ether;
        uint256 price = 10 ether;

        ICLOB.PostLimitOrderResult[] memory results = new ICLOB.PostLimitOrderResult[](10);
        setupTokens(Side.BUY, user, amountInBase, price, true);

        vm.startPrank(user);
        for (uint256 i = 0; i < 10; i++) {
        // Prepare arguments
            ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
                clientOrderId: uint96(i),
                amountInBase: amountInBase / 10,
                price: price,
                cancelTimestamp: TOMORROW,
                side: Side.BUY,
                limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED

            });
            results[i] = clob.postLimitOrder(user, args);
        }

        // cancel one order
        uint256[] memory orderIds = new uint256[](1);
        orderIds[0] = results[0].orderId;

        ICLOB.CancelArgs memory cArgs = ICLOB.CancelArgs({orderIds: orderIds});
        clob.cancel(user, cArgs);

        orderIds = new uint256[](10);
        for (uint256 i = 0; i < 10; i++) {
            orderIds[i] = results[i].orderId;
        }

        // should succeed even with an order missing in the orderbook
        cArgs = ICLOB.CancelArgs({orderIds: orderIds});
        clob.cancel(user, cArgs);
    }

    function getPreCancelState(uint256 id) internal view returns (CancelState memory state) {
        Order memory order = clob.getOrder(id);
        state.order = order;

        Limit memory limit = clob.getLimit(order.price, order.side);
        state.limitNumOrders = limit.numOrders;

        (uint256 quoteOi, uint256 baseOi) = clob.getOpenInterest();

        if (order.side == Side.BUY) {
            state.openInterest = quoteOi;
            state.ordersPerSide = clob.getNumBids();
        } else {
            state.openInterest = baseOi;
            state.ordersPerSide = clob.getNumAsks();
        }
    }

    function assertPostCancelState(CancelState memory s) internal view {
        Limit memory limit = clob.getLimit(s.order.price, s.order.side);

        if (limit.headOrder.unwrap() != 0) {
            Order memory o = clob.getOrder(limit.headOrder.unwrap());
            for (uint256 i = 0; i < limit.numOrders; i++) {
                assertFalse(o.nextOrderId.unwrap() == s.order.id.unwrap());
                o = clob.getOrder(o.nextOrderId.unwrap());
            }
        }

        assertEq(s.limitNumOrders, limit.numOrders + 1);
        uint256 prev = s.order.prevOrderId.unwrap();
        uint256 next = s.order.nextOrderId.unwrap();

        if (prev > 0) {
            Order memory p = clob.getOrder(prev);
            assertEq(p.nextOrderId.unwrap(), next);
        }

        if (next > 0) {
            Order memory n = clob.getOrder(next);
            assertEq(n.prevOrderId.unwrap(), prev);
        }

        (uint256 quoteOi, uint256 baseOi) = clob.getOpenInterest();

        if (s.order.side == Side.BUY) {
            uint256 oi = clob.getQuoteTokenAmount(s.order.price, s.order.amount);
            assertEq(s.openInterest, quoteOi + oi);
            assertEq(s.ordersPerSide, clob.getNumBids() + 1);
        } else {
            uint256 oi = s.order.amount;
            assertEq(s.openInterest, baseOi + oi);
            assertEq(s.ordersPerSide, clob.getNumAsks() + 1);
        }

        Order memory nil = clob.getOrder(s.order.id.unwrap());
        assertEq(nil.id.unwrap(), 0);
        assertEq(nil.prevOrderId.unwrap(), 0);
        assertEq(nil.nextOrderId.unwrap(), 0);
        assertEq(nil.amount, 0);
        assertEq(nil.price, 0);
        assertEq(nil.owner, address(0));
        assertEq(uint8(nil.side), 0);
    }

    function test_order_is_null_expect_emit() public {
        // Place and cancel and order
        address user = users[0];
        uint256 amountInBase = 2 ether;
        uint256 price = 10 ether;

        // Deposit sufficient quote tokens
        //uint256 quoteAmountToDeposit =
        setupTokens(Side.BUY, user, amountInBase, price, true);

        //uint256 balanceBefore = clob.getQuoteToken().balanceOf(user);

        // Prepare arguments
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            clientOrderId: 0,
            amountInBase: amountInBase,
            price: price,
            cancelTimestamp: TOMORROW,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED

        });

        vm.startPrank(user);

        // Post limit order and get state
        ICLOB.PostLimitOrderResult memory result = clob.postLimitOrder(user, args);
        uint256 id = result.orderId;

        uint256[] memory orderIds = new uint256[](1);
        orderIds[0] = result.orderId;

        ICLOB.CancelArgs memory cArgs = ICLOB.CancelArgs({orderIds: orderIds});
        clob.cancel(user, cArgs);

        // cancel the already cancelled order
        vm.expectEmit();
        emit CLOB.CancelFailed(clob.getEventNonce() + 1, id, user);
        clob.cancel(user, cArgs);
    }
    function testFuzz_wrong_owner_expect_revert(uint8 idx, address caller) public {
        vm.assume(idx < users.length - 1);
        // Place and cancel and order
        address user = users[idx];
        vm.assume(user != caller);
        uint256 amountInBase = 2 ether;
        uint256 price = 10 ether;

        // Deposit sufficient quote tokens
        //uint256 quoteAmountToDeposit =
        setupTokens(Side.BUY, user, amountInBase, price, true);

        // uint256 balanceBefore = clob.getQuoteToken().balanceOf(user);
        // Prepare arguments
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            clientOrderId: 0,
            amountInBase: amountInBase,
            price: price,
            cancelTimestamp: TOMORROW,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED

        });

        vm.prank(user);
        // Post limit order and get state
        ICLOB.PostLimitOrderResult memory result = clob.postLimitOrder(user, args);

        uint256[] memory orderIds = new uint256[](1);
        orderIds[0] = result.orderId;

        ICLOB.CancelArgs memory cArgs = ICLOB.CancelArgs({orderIds: orderIds});

        vm.startPrank(caller);
        vm.expectRevert(CLOB.CancelUnauthorized.selector);
        clob.cancel(caller, cArgs);
    }
}
