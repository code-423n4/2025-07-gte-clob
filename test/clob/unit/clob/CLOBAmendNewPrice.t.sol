// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {CLOBTestBase} from "test/clob/utils/CLOBTestBase.sol";
import {CLOB, ICLOB, Order, OrderId, Limit, Side, OrderLib} from "contracts/clob/CLOB.sol";
import {MarketSettings} from "contracts/clob/types/Book.sol";
import "forge-std/console.sol";
contract CLOBAmendNewPrice is CLOBTestBase {
    using SafeTransferLib for address;

    struct IncreaseState {
        Order order;
        uint256 limitNumOrders;
        uint256 newPrice;
        uint256 quoteAccountBalance;
        uint256 baseAccountBalance;
        uint256 quoteTokenBalance;
        uint256 baseTokenBalance;
        uint256 quoteOi;
        uint256 baseOi;
        uint256 numBids;
        uint256 numAsks;
    }

    IncreaseState state;
    address user;

    function setUp() public override {
        super.setUp();
        user = users[1];
    }

    function test_Amend_NewPrice_IncreaseBid_Account() public {
        uint256 amountInBase = 10 ether;
        uint256 price = 100 ether;
        uint256 newPrice = state.newPrice = 110 ether;

        // Deposit sufficient base tokens
        setupTokens(Side.BUY, user, amountInBase, newPrice, true);

        // Prepare arguments
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            clientOrderId: 0,
            amountInBase: amountInBase,
            price: price,
            cancelTimestamp: TOMORROW,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.POST_ONLY
        });

        vm.startPrank(user);
        // Post limit order
        ICLOB.PostLimitOrderResult memory result = clob.postLimitOrder(user, args);
        // Cache pre-increase state
        cachePreIncreaseState(result.orderId);

        ICLOB.AmendArgs memory rArgs = ICLOB.AmendArgs({
            orderId: result.orderId,
            amountInBase: amountInBase,
            price: newPrice,
            cancelTimestamp: TOMORROW,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.POST_ONLY
        });

        // change side
        (int256 quoteDelta, int256 baseDelta) = clob.amend(user, rArgs);
        // Assert post-increase state
        assertPostNewPrice(quoteDelta, baseDelta);
    }
    function test_Amend_NewPrice_IncreaseAsk_Account() public {
        uint256 amountInBase = 10 ether;
        uint256 price = 100 ether;
        uint256 newPrice = state.newPrice = 110 ether;

        // Deposit sufficient base tokens
        setupTokens(Side.SELL, user, amountInBase, price, true);

        // Prepare arguments
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            clientOrderId: 0,
            amountInBase: amountInBase,
            price: price,
            cancelTimestamp: TOMORROW,
            side: Side.SELL,
            limitOrderType: ICLOB.LimitOrderType.POST_ONLY
        });

        vm.startPrank(user);
        // Post limit order
        ICLOB.PostLimitOrderResult memory result = clob.postLimitOrder(user, args);

        // Cache pre-increase state
        cachePreIncreaseState(result.orderId);
        ICLOB.AmendArgs memory rArgs = ICLOB.AmendArgs({
            orderId: result.orderId,
            amountInBase: amountInBase,
            price: newPrice,
            cancelTimestamp: TOMORROW,
            side: Side.SELL,
            limitOrderType: ICLOB.LimitOrderType.POST_ONLY
        });

        // change side
        (int256 quoteDelta, int256 baseDelta) = clob.amend(user, rArgs);
        // Assert post-increase state
        assertPostNewPrice(quoteDelta, baseDelta);
    }
    // INVARIANTS //
    function cachePreIncreaseState(uint256 id) internal {
        Order memory order = clob.getOrder(id);
        state.order = order;

        Limit memory limit = clob.getLimit(order.price, order.side);
        state.limitNumOrders = limit.numOrders;

        (state.quoteOi, state.baseOi) = clob.getOpenInterest();
        state.numBids = clob.getNumBids();
        state.numAsks = clob.getNumAsks();
        state.quoteAccountBalance = clobManager.accountManager().getAccountBalance(user, address(clob.getQuoteToken()));
        state.baseAccountBalance = clobManager.accountManager().getAccountBalance(user, address(clob.getBaseToken()));
        state.quoteTokenBalance = clob.getQuoteToken().balanceOf(user);
        state.baseTokenBalance = clob.getBaseToken().balanceOf(user);
    }
    function assertPostNewPrice(int256 quoteTokenDelta, int256 baseTokenDelta)
        internal
        view
    {
        (uint256 quoteOi, uint256 baseOi) = clob.getOpenInterest();
        int256 quoteChange;

        if (state.order.side == Side.BUY) {
            int256 oldQuote = int256(clob.getQuoteTokenAmount(state.order.price, state.order.amount));
            int256 newQuote = int256(clob.getQuoteTokenAmount(state.newPrice, state.order.amount));
            quoteChange = oldQuote - newQuote;
        }

        assertEq(quoteTokenDelta, quoteChange, "quote token delta != expected");
        assertEq(baseTokenDelta, 0, "base token delta != expected");

        assertEq(
            state.limitNumOrders,
            clob.getLimit(state.newPrice, state.order.side).numOrders,
            "limit num orders != expected"
        );

        assertEq(uint256(int256(state.quoteOi) - quoteChange), quoteOi, "quote oi != expected");
        assertEq(state.baseOi, baseOi, "base oi != expected");

        assertEq(
            state.quoteAccountBalance,
            uint256(int256(clobManager.accountManager().getAccountBalance(user, address(clob.getQuoteToken()))) - quoteChange),
            "quote account balance != expected"
        );

        assertEq(state.quoteTokenBalance, clob.getQuoteToken().balanceOf(user), "quote token balance != expected");

        assertEq(
            state.baseAccountBalance,
            clobManager.accountManager().getAccountBalance(user, address(clob.getBaseToken())),
            "base account balance != expected"
        );

        assertEq(state.baseTokenBalance, clob.getBaseToken().balanceOf(user), "base token balance != expected");

        Order memory order = clob.getOrder(state.order.id.unwrap());
        assertEq(order.amount, state.order.amount, "order amount != expected");
    }
}
