// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {CLOBTestBase} from "test/clob/utils/CLOBTestBase.sol";
import {CLOB, ICLOB, Order, OrderId, Limit, Side, OrderLib} from "contracts/clob/CLOB.sol";
import {MarketSettings} from "contracts/clob/types/Book.sol";
contract CLOBAmendIncreaseTest is CLOBTestBase {
    using SafeTransferLib for address;

    struct IncreaseState {
        Order order;
        uint256 increaseAmount;
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

    function test_increase_base_account() public {
        uint256 amountInBase = 10 ether;
        uint256 price = 100 ether;

        // Deposit sufficient base tokens
        setupTokens(Side.SELL, user, amountInBase, price, true);
        // Prepare arguments
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price,
            cancelTimestamp: TOMORROW,
            side: Side.SELL,
            limitOrderType: ICLOB.LimitOrderType.POST_ONLY
        });

        vm.startPrank(user);

        // Post limit order
        ICLOB.PostLimitOrderResult memory result = clob.postLimitOrder(user, args);

        uint256 newAmount = 13 ether;
        uint256 increaseAmount = newAmount - amountInBase;
        ICLOB.AmendArgs memory rArgs = ICLOB.AmendArgs({
            orderId: result.orderId,
            amountInBase: newAmount,
            price: price,
            cancelTimestamp: TOMORROW,
            side: Side.SELL,
            limitOrderType: ICLOB.LimitOrderType.POST_ONLY
        });

        setupTokens(Side.SELL, user, increaseAmount, price, true);
        cachePreIncreaseState(result.orderId, increaseAmount);

        vm.prank(user);
        (int256 quoteDelta, int256 baseDelta) = clob.amend(user, rArgs);

        assertAmendIncreaseResult(quoteDelta, baseDelta, increaseAmount);
        assertPostIncreaseState();
    }
    function test_increase_quote_account() public {
        uint256 amountInBase = 10 ether;
        uint256 price = 100 ether;

        // Deposit sufficient base tokens
        setupTokens(Side.BUY, user, amountInBase, price, true);

        // Prepare arguments
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price,
            cancelTimestamp: TOMORROW,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.POST_ONLY
        });

        vm.startPrank(user);
        // Post limit order
        ICLOB.PostLimitOrderResult memory result = clob.postLimitOrder(user, args);

        uint256 newAmount = 13 ether;
        uint256 increaseAmount = newAmount - amountInBase;

        ICLOB.AmendArgs memory rArgs = ICLOB.AmendArgs({
            orderId: result.orderId,
            amountInBase: newAmount,
            price: price,
            cancelTimestamp: TOMORROW,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.POST_ONLY
        });

        setupTokens(Side.BUY, user, increaseAmount, price, true);
        cachePreIncreaseState(result.orderId, increaseAmount);

        vm.prank(user);
        (int256 quoteDelta, int256 baseDelta) = clob.amend(user, rArgs);

        assertAmendIncreaseResult(quoteDelta, baseDelta, increaseAmount);
        assertPostIncreaseState();
    }
    // INVARIANTS //
    function cachePreIncreaseState(uint256 id, uint256 increaseAmount) internal {
        Order memory order = clob.getOrder(id);
        state.order = order;
        state.increaseAmount = increaseAmount;

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
    function assertPostIncreaseState() internal view {
        (uint256 quoteOi, uint256 baseOi) = clob.getOpenInterest();
        uint256 quoteIncreased;
        uint256 baseIncreased;

        if (state.order.side == Side.BUY) {
            quoteIncreased = clob.getQuoteTokenAmount(state.order.price, state.increaseAmount);
            assertEq(state.quoteOi + quoteIncreased, quoteOi, "quote oi != expected");
            assertEq(state.baseOi, baseOi, "base oi != expected");
        } else {
            baseIncreased = state.increaseAmount;
            assertEq(state.baseOi + baseIncreased, baseOi, "base oi != expected");
            assertEq(state.quoteOi, quoteOi, "quote oi != expected");
        }

        assertEq(
            state.quoteAccountBalance,
            clobManager.accountManager().getAccountBalance(user, address(clob.getQuoteToken())) + quoteIncreased,
            "quote account balance != expected"
        );

        assertEq(
            state.baseAccountBalance,
            clobManager.accountManager().getAccountBalance(user, address(clob.getBaseToken())) + baseIncreased,
            "base account balance != expected"
        );

        assertEq(state.quoteTokenBalance, clob.getQuoteToken().balanceOf(user), "quote token balance != expected");
        assertEq(state.baseTokenBalance, clob.getBaseToken().balanceOf(user), "base token balance != expected");

        Order memory order = clob.getOrder(state.order.id.unwrap());
        assertEq(order.amount, state.order.amount + state.increaseAmount, "order amount != expected");
    }
    function assertAmendIncreaseResult(int256 quoteTokenDelta, int256 baseTokenDelta, uint256 increaseAmount)
        internal
        view
    {
        if (state.order.side == Side.BUY) {
            uint256 quoteIncreased = clob.getQuoteTokenAmount(state.order.price, increaseAmount);
            assertEq(quoteTokenDelta, -int256(quoteIncreased), "quote token delta != expected");
            assertEq(baseTokenDelta, 0, "base token delta != expected");
        } else {
            assertEq(quoteTokenDelta, 0, "quote token delta != expected");
            assertEq(baseTokenDelta, -int256(increaseAmount), "base token delta != expected");
        }
    }
}
