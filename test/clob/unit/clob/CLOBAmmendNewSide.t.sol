// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {CLOBTestBase} from "test/clob/utils/CLOBTestBase.sol";
import {CLOB, ICLOB, Order, OrderId, Limit, Side, OrderLib} from "contracts/clob/CLOB.sol";
import {MarketSettings} from "contracts/clob/types/Book.sol";
contract CLOBAmendNewSide is CLOBTestBase {
    using SafeTransferLib for address;

    struct IncreaseState {
        Order order;
        uint256 limitNumOrders;
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

    function test_CLOBAmend_NewSide_FromBid_Account() public {
        uint256 amountInBase = 10 ether;
        uint256 price = 100 ether;

        // Deposit sufficient base tokens
        setupTokens(Side.BUY, user, amountInBase, price, true);
        setupTokens(Side.SELL, user, amountInBase, price, true);

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
            price: price,
            cancelTimestamp: TOMORROW,
            side: Side.SELL,
            limitOrderType: ICLOB.LimitOrderType.POST_ONLY

        });

        // change side
        (int256 quoteDelta, int256 baseDelta) = clob.amend(user, rArgs);

        // Assert post-increase state
        assertPostNewSideState();
        assertAmendNewSideResult(quoteDelta, baseDelta);
    }
    function test_CLOBAmend_NewSide_FromAsk_Account() public {
        uint256 amountInBase = 10 ether;
        uint256 price = 100 ether;

        uint256 cancelTimestamp = block.timestamp + 1 days;

        // Deposit sufficient base tokens
        setupTokens(Side.BUY, user, amountInBase, price, true);
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
            price: price,
            cancelTimestamp: TOMORROW,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.POST_ONLY
        });

        // change side
        (int256 quoteDelta, int256 baseDelta) = clob.amend(user, rArgs);

        // Assert post-increase state
        assertPostNewSideState();
        assertAmendNewSideResult(quoteDelta, baseDelta);
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
    function assertPostNewSideState() internal view {
        (uint256 quoteOi, uint256 baseOi) = clob.getOpenInterest();
        int256 quoteChange;
        int256 baseChange;

        if (state.order.side == Side.BUY) {
            quoteChange = -int256(clob.getQuoteTokenAmount(state.order.price, state.order.amount));
            baseChange = int256(state.order.amount);
        } else {
            baseChange = -int256(state.order.amount);
            quoteChange = int256(clob.getQuoteTokenAmount(state.order.price, state.order.amount));
        }

        assertEq(uint256(int256(state.quoteOi) + quoteChange), quoteOi, "quote oi != expected");
        assertEq(uint256(int256(state.baseOi) + baseChange), baseOi, "base oi != expected");

        assertEq(
            state.quoteAccountBalance,
            uint256(int256(clobManager.accountManager().getAccountBalance(user, address(clob.getQuoteToken()))) + quoteChange),
            "quote account balance != expected"
        );

        assertEq(
            state.baseAccountBalance,
            uint256(int256(clobManager.accountManager().getAccountBalance(user, address(clob.getBaseToken()))) + baseChange),
            "base account balance != expected"
        );

        assertEq(state.quoteTokenBalance, clob.getQuoteToken().balanceOf(user), "quote token balance != expected");
        assertEq(state.baseTokenBalance, clob.getBaseToken().balanceOf(user), "base token balance != expected");

        Order memory order = clob.getOrder(state.order.id.unwrap());
        assertEq(order.amount, state.order.amount, "order amount != expected");
        assertTrue(state.order.side != order.side, "order side != expected");
    }
    function assertAmendNewSideResult(int256 quoteTokenDelta, int256 baseTokenDelta) internal view {
        uint256 baseAmount = state.order.amount;
        uint256 quoteAmount = clob.getQuoteTokenAmount(state.order.price, baseAmount);

        if (state.order.side == Side.BUY) {
            assertEq(quoteTokenDelta, int256(quoteAmount), "quote token delta != expected");
            assertEq(baseTokenDelta, -int256(baseAmount), "base token delta != expected");
        } else {
            assertEq(quoteTokenDelta, -int256(quoteAmount), "quote token delta != expected");
            assertEq(baseTokenDelta, int256(baseAmount), "base token delta != expected");
        }
    }
}
