// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {CLOBTestBase, MatchQuantities} from "test/clob/utils/CLOBTestBase.sol";
import {CLOBManager} from "contracts/clob/CLOBManager.sol";
import {AccountManager} from "contracts/account-manager/AccountManager.sol";
import {CLOB} from "contracts/clob/CLOB.sol";
import {ICLOB} from "contracts/clob/ICLOB.sol";
import {Side, Order} from "contracts/clob/types/Order.sol";
import {BookLib} from "contracts/clob/types/Book.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {TestPlus} from "lib/solady/test/utils/TestPlus.sol";
import {ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {IERC20Errors} from "@openzeppelin/interfaces/draft-IERC6093.sol";
import "forge-std/console.sol";

contract CLOBPostLimitOrderTest is CLOBTestBase, TestPlus {

    function testPostLimitBuyOrder_GTC_Success_Account() public {
        testPostLimitBuyOrder_GTC_Success_Helper();
    }

    /// @dev Test posting a valid limit buy order with sufficient balance and approvals
    function testPostLimitBuyOrder_GTC_Success_Helper() private {
        address user = users[0];
        uint256 amountInBase = 2 ether;
        uint256 price = 100 ether;
        setupTokens(Side.BUY, user, amountInBase, price, true);
        // Prepare arguments
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price,
            cancelTimestamp: NEVER,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
        });
        // Expect events
        vm.expectEmit(true, true, true, true);
        emit CLOB.LimitOrderSubmitted(clob.getEventNonce() + 1, user, 1, args);
        vm.expectEmit(true, true, true, true);
        emit CLOB.LimitOrderProcessed(clob.getEventNonce() + 3, user, 1, amountInBase, -int256(0), int256(0), 0);

        // Post limit order
        vm.startPrank(user);
        ICLOB.PostLimitOrderResult memory result = clob.postLimitOrder(user, args);
        vm.stopPrank();
        // Verify results
        assertEq(result.orderId, 1, "Order ID should be 1");
        assertEq(result.amountPostedInBase, amountInBase, "Remaining amount should match");
        assertEq(result.quoteTokenAmountTraded, -int256(0), "Quote token change should be zero");
        assertEq(result.baseTokenAmountTraded, int256(0), "Base token change should be zero");
        // Check order book state
        Order memory order = clob.getOrder(1);
        assertEq(order.owner, user, "Order owner should be user");
        assertEq(order.amount, amountInBase, "Order amount should match");
        assertEq(order.price, price, "Order price should match");
        // User has deposited all tokens and should have no balance left
        assertTokenBalance(user, Side.BUY, 0);
        assertTokenBalance(user, Side.SELL, 0);
    }

    function testPostLimitSellOrder_GTC_Success_Account() public {
        testPostLimitSellOrder_GTC_Success_Helper();
    }

    /// @dev Test posting a valid limit sell order with sufficient balance and approvals
    function testPostLimitSellOrder_GTC_Success_Helper() private {
        address user = users[0];
        uint256 amountInBase = 2 ether;
        uint256 price = 100 ether;

        setupTokens(Side.SELL, user, amountInBase, price, true);

        // Prepare arguments
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price,
            cancelTimestamp: NEVER,
            side: Side.SELL,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
        });

        // Expect events
        vm.expectEmit(true, true, true, true);
        emit CLOB.LimitOrderSubmitted(clob.getEventNonce() + 1, user, 1, args);

        vm.expectEmit(true, true, true, true);
        emit CLOB.LimitOrderProcessed(clob.getEventNonce() + 3, user, 1, amountInBase, int256(0), -int256(0), 0);

        // Post limit order
        vm.startPrank(user);
        ICLOB.PostLimitOrderResult memory result = clob.postLimitOrder(user, args);
        vm.stopPrank();

        // Verify results
        assertEq(result.orderId, 1, "Order ID should be 1");
        assertEq(result.amountPostedInBase, amountInBase, "Remaining amount should match");
        assertEq(result.quoteTokenAmountTraded, int256(0), "Quote token change should be zero");
        assertEq(result.baseTokenAmountTraded, -int256(0), "Base token change should be zero");

        // Check order book state
        Order memory order = clob.getOrder(1);
        assertEq(order.owner, user, "Order owner should be user");
        assertEq(order.amount, amountInBase, "Order amount should match");
        assertEq(order.price, price, "Order price should match");

        // User has deposited all tokens and should have no balance left
        assertTokenBalance(user, Side.BUY, 0);
        assertTokenBalance(user, Side.SELL, 0);
    }

    error OrderIdInUse();
    function testPostLimitOrderCustomClientID(address account, uint96 id) public {
        vm.assume(id != 0);
        vm.assume(account != address(0));
        vm.assume(account != address(clob));
        vm.assume(account != address(clobManager));

        uint256 amountInBase = 2 ether;
        uint256 price = 100 ether;

        setupTokens(Side.SELL, account, amountInBase, price, true);

        // Prepare arguments
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: id,
            price: price,
            cancelTimestamp: NEVER,
            side: Side.SELL,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
        });

        uint256 expectedId = uint256(bytes32(abi.encodePacked(account, id)));

        // Expect events
        vm.expectEmit(true, true, true, true);
        emit CLOB.LimitOrderSubmitted(clob.getEventNonce() + 1, account, expectedId, args);

        vm.expectEmit(true, true, true, true);
        emit CLOB.LimitOrderProcessed(
            clob.getEventNonce() + 3, account, expectedId, amountInBase, int256(0), int256(0), 0
        );

        // Post limit order
        vm.startPrank(account);

        uint256 orderId = clob.postLimitOrder(account, args).orderId;
        assertEq(orderId, expectedId, "Order ID should match the expected ID");

        vm.expectRevert(OrderIdInUse.selector);
        clob.postLimitOrder(account, args);
    }

    /// @dev Test posting a limit order with invalid price (price out of bounds)
    function testPostLimitOrder_InvalidPrice_ZeroPrice() public {
        address user = users[0];
        uint256 amountInBase = 2 ether;
        uint256 price = 0;

        // Deposit sufficient tokens
        setupTokens(Side.BUY, user, amountInBase, price, true);

        // Prepare arguments with invalid price
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price, // Invalid price
            cancelTimestamp: TOMORROW,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED

        });

        // Expect revert
        vm.expectRevert(BookLib.LimitPriceInvalid.selector);
        vm.startPrank(user);

        clob.postLimitOrder(user, args);
        vm.stopPrank();
    }

    function testPostLimitOrder_InvalidPrice_TickConfirmation() public {
        address user = users[0];
        uint256 amountInBase = 2 ether;
        uint256 price = TICK_SIZE * 10 + (TICK_SIZE / 2); // Invalid price

        // Deposit sufficient tokens
        setupTokens(Side.BUY, user, amountInBase, price, true);

        // Prepare arguments with invalid price
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price, // Invalid price
            cancelTimestamp: TOMORROW,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED

        });

        // Expect revert
        vm.expectRevert(BookLib.LimitPriceInvalid.selector);
        vm.startPrank(user);

        clob.postLimitOrder(user, args);
        vm.stopPrank();
    }

    /// @dev Test posting a limit order with invalid amount (amount out of bounds)
    function testPostLimitOrder_InvalidAmount() public {
        address user = users[0];
        uint256 amountInBase = MIN_LIMIT_ORDER_AMOUNT_IN_BASE - 1; // Invalid amount (assuming amount must be > 0)
        uint256 price = 100 ether;

        // Deposit sufficient tokens
        setupTokens(Side.BUY, user, amountInBase, price, true);

        // Prepare arguments with invalid amount
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0, // Invalid amount
            price: price,
            cancelTimestamp: TOMORROW,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED

        });

        // Expect revert
        vm.expectRevert(BookLib.LimitOrderAmountInvalid.selector);
        vm.startPrank(user);

        clob.postLimitOrder(user, args);
        vm.stopPrank();
    }

    function testPostLimitOrder_PostOnlyWouldBeFilled_BuyAccount() public {
        testPostLimitOrder_PostOnlyWouldBeFilled_Helper(Side.BUY);
    }

    function testPostLimitOrder_PostOnlyWouldBeFilled_SellAccount() public {
        testPostLimitOrder_PostOnlyWouldBeFilled_Helper(Side.SELL);
    }

    /// @dev Test posting a post-only limit order that would be immediately filled (should revert)
    function testPostLimitOrder_PostOnlyWouldBeFilled_Helper(Side side) internal {
        address user = users[0];
        uint256 amountInBase = 2 ether;
        uint256 price = 100 ether;

        // First, place an existing opposite-side order to create a match scenario
        address otherUser = users[1];

        // Deposit base tokens for sell order
        Side reverseSide = side == Side.BUY ? Side.SELL : Side.BUY;

        setupTokens(reverseSide,  otherUser, amountInBase, price, true);
        setupTokens(side,  user, amountInBase, price, true);

        // Place sell order at the same price at reverse side
        ICLOB.PostLimitOrderArgs memory sellOrderArgs = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price,
            cancelTimestamp: TOMORROW,
            side: reverseSide,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
        });

        vm.prank(otherUser);
        clob.postLimitOrder(otherUser, sellOrderArgs);

        // Now, attempt to place a post-only buy order that would be filled
        // Prepare post-only buy order
        ICLOB.PostLimitOrderArgs memory postOnlyBuyArgs = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price,
            cancelTimestamp: TOMORROW,
            side: side,
            limitOrderType: ICLOB.LimitOrderType.POST_ONLY
        });

        // Expect revert due to post-only order being filled immediately
        vm.expectRevert(CLOB.PostOnlyOrderWouldFill.selector);
        vm.startPrank(user);

        clob.postLimitOrder(user, postOnlyBuyArgs);
        vm.stopPrank();
    }

    /// @dev Test posting a limit order when max number of orders is reached and new order is not competitive (should revert)
    function testPostLimitOrder_MaxOrdersNotCompetitive_BuyAccount() public {
        testPostLimitOrder_MaxOrdersNotCompetitive_Helper(Side.BUY);
    }

    /// @dev Test posting a limit order when max number of orders is reached and new order is not competitive (should revert) - Buy Side
    /// @dev Test posting a limit order when max number of orders is reached and new order is not competitive (should revert) - Sell Side
    function testPostLimitOrder_MaxOrdersNotCompetitive_SellAccount() public {
        testPostLimitOrder_MaxOrdersNotCompetitive_Helper(Side.SELL);
    }

    function testPostLimitOrder_MaxOrdersNotCompetitive_Helper(Side side) internal {
        // Simulate the order book reaching max number of orders
        address user = users[0];
        uint256 amountInBase = 2 ether;
        uint256 price = 100 ether;

        setupTokens(side,  user, amountInBase * (MAX_NUM_LIMITS_PER_SIDE + 1), price, true);

        // Place MAX_NUM_LIMITS_PER_SIDE at different prices to fill the order book
        vm.startPrank(user);
        for (uint256 i = 0; i < MAX_NUM_LIMITS_PER_SIDE; i++) {
            // Create different prices for each order to fill up the tree
            side == Side.BUY ? price -= TICK_SIZE : price += TICK_SIZE;
            ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
                amountInBase: amountInBase,
                clientOrderId: 0,
                price: price,
                cancelTimestamp: NEVER,
                side: side,
                limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
            });
            clob.postLimitOrder(user, args);
        }

        // Attempt to place a new order at an even less competitive price
        uint256 nonCompetitivePrice = side == Side.BUY ? price - TICK_SIZE : price + TICK_SIZE;

        ICLOB.PostLimitOrderArgs memory newOrderArgs = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: nonCompetitivePrice,
            cancelTimestamp: NEVER,
            side: side,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
        });

        // Expect revert due to max orders in book and order not being competitive
        vm.expectRevert(CLOB.MaxOrdersInBookPostNotCompetitive.selector);
        clob.postLimitOrder(user, newOrderArgs);
        vm.stopPrank();
    }

    /// @dev Test posting a limit order when max number of orders is reached and new order is competitive (should replace existing order) - Buy Side
    function testPostLimitOrder_MaxOrdersCompetitive_BuyAccount() public {
        testPostLimitOrder_MaxOrdersCompetitive_Helper(Side.BUY);
    }

    /// @dev Test posting a limit order when max number of orders is reached and new order is competitive (should replace existing order) - Buy Side
    /// @dev Test posting a limit order when max number of orders is reached and new order is competitive (should replace existing order) - Sell Side
    function testPostLimitOrder_MaxOrdersCompetitive_SellAccount() public {
        testPostLimitOrder_MaxOrdersCompetitive_Helper(Side.SELL);
    }

    struct MaxOrdersParams {
        uint256 orderId;
        address user;
        address moreCompetitiveUser;
        uint256 lessCompetitivePrice;
        uint256 moreCompetitivePrice;
        uint256 amountInBase;
        uint256 amountInQuote;
        uint32  cancelTimestamp;
    }

    function testPostLimitOrder_MaxOrdersCompetitive_Helper(Side side) internal {
        MaxOrdersParams memory p;
        // Simulate the order book reaching max number of orders
        p.orderId = clob.getNextOrderId();
        p.user = users[0];
        p.moreCompetitiveUser = users[1];
        p.lessCompetitivePrice = 100 ether;
        p.moreCompetitivePrice =
            side == Side.BUY ? p.lessCompetitivePrice + TICK_SIZE : p.lessCompetitivePrice - TICK_SIZE;
        p.amountInBase = 10 ether;
        p.amountInQuote = clob.getQuoteTokenAmount(p.lessCompetitivePrice, p.amountInBase);
        p.cancelTimestamp = TOMORROW;

        setupTokens(side,  p.user, p.amountInBase * (MAX_NUM_LIMITS_PER_SIDE), p.lessCompetitivePrice, true);
        setupTokens(side,  p.moreCompetitiveUser, p.amountInBase, p.moreCompetitivePrice, true);

        // Place MAX_NUM_LIMITS_PER_SIDE at a less competitive price to fill the order book
        vm.startPrank(p.user);
        for (uint256 i = 0; i < MAX_NUM_LIMITS_PER_SIDE; i++) {
            // Creates a new limit that is less competitive than the order
            side == Side.BUY ? p.lessCompetitivePrice -= TICK_SIZE : p.lessCompetitivePrice += TICK_SIZE;
            ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
                amountInBase: p.amountInBase,
                price: p.lessCompetitivePrice,
                cancelTimestamp: p.cancelTimestamp,
                side: side,
                clientOrderId: 0,
                limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
            });
            clob.postLimitOrder(p.user, args);
        }

        p.moreCompetitivePrice =
            side == Side.BUY ? 100 ether + TICK_SIZE : 100 ether - TICK_SIZE;

        // Attempt to place a new order at a more competitive price
        ICLOB.PostLimitOrderArgs memory newOrderArgs = ICLOB.PostLimitOrderArgs({
            amountInBase: p.amountInBase,
            price: p.moreCompetitivePrice,
            cancelTimestamp: p.cancelTimestamp,
            side: side,
            clientOrderId: 0,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
        });

        uint256 quoteBalBefore = clobManager.accountManager().getAccountBalance(p.user, address(clob.getQuoteToken()));
        uint256 baseBalBefore = clobManager.accountManager().getAccountBalance(p.user, address(clob.getBaseToken()));

        // Calculate the quote amount for the least competitive order that will be canceled
        uint256 leastCompetitivePrice = p.lessCompetitivePrice; // This is the final price after the loop
        uint256 expectedRefundQuote = clob.getQuoteTokenAmount(leastCompetitivePrice, p.amountInBase);

        vm.startPrank(p.moreCompetitiveUser);
        // Expect events for order cancellation and submission
        vm.expectEmit(true, true, true, true);
        emit CLOB.LimitOrderSubmitted(
            clob.getEventNonce() + 1, p.moreCompetitiveUser, p.orderId + MAX_NUM_LIMITS_PER_SIDE, newOrderArgs
        );

        vm.expectEmit(true, true, true, true);
        if (side == Side.BUY) {
            emit CLOB.OrderCanceled(
                clob.getEventNonce() + 2, p.orderId + MAX_NUM_LIMITS_PER_SIDE - 1, p.user, expectedRefundQuote, 0, ICLOB.CancelType.NON_COMPETITIVE
            );
        } else {
            emit CLOB.OrderCanceled(
                clob.getEventNonce() + 2, p.orderId + MAX_NUM_LIMITS_PER_SIDE - 1, p.user, 0, p.amountInBase, ICLOB.CancelType.NON_COMPETITIVE
            );
        }

        vm.expectEmit(true, true, true, true);
        emit CLOB.LimitOrderProcessed(
            clob.getEventNonce() + 4,
            p.moreCompetitiveUser,
            p.orderId + MAX_NUM_LIMITS_PER_SIDE,
            p.amountInBase,
            int256(0),
            int256(0),
            0
        );

        // Post the new order which should replace the least competitive one
        clob.postLimitOrder(p.moreCompetitiveUser, newOrderArgs);
        vm.stopPrank();
        uint256 quoteBalAfter = clobManager.accountManager().getAccountBalance(p.user, address(clob.getQuoteToken()));
        uint256 baseBalAfter = clobManager.accountManager().getAccountBalance(p.user, address(clob.getBaseToken()));

        // Verify that the order book still has MAX_NUM_LIMITS_PER_SIDE
        if (side == Side.BUY) {
            assertEq(quoteBalAfter - quoteBalBefore, expectedRefundQuote, "incorrect quote token bal");
            assertEq(baseBalAfter, baseBalBefore, "incorrect base token bal");
            assertEq(clob.getNumBids(), MAX_NUM_LIMITS_PER_SIDE, "Order book should still have max number of bids");
        } else {
            assertEq(quoteBalAfter, quoteBalBefore, "incorrect quote token bal");
            assertEq(baseBalAfter - baseBalBefore, p.amountInBase, "incorrect base token bal");
            assertEq(clob.getNumAsks(), MAX_NUM_LIMITS_PER_SIDE, "Order book should still have max number of asks");
        }
    }

    // @dev Test posting a limit order with insufficient token balance (should revert)
    function testPostLimitBuyOrder_InsufficientBalance() public {
        address user = users[2];
        uint256 amountInBase = 1 ether;
        uint256 price = 100 ether;

        // Do not deposit quote tokens or deposit insufficient amount
        setupTokens(Side.BUY, user, amountInBase / 2, price, true);

        // Prepare arguments
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price,
            cancelTimestamp: TOMORROW,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED

        });

        vm.startPrank(user);
        // Expect revert due to insufficient token balance
        vm.expectRevert(AccountManager.BalanceInsufficient.selector);
        clob.postLimitOrder(user, args);
        vm.stopPrank();
    }

    /// @dev Test posting a limit order with an expired cancelTimestamp (should revert)
    function testPostLimitOrder_ExpiredCancelTimestamp() public {
        address user = users[4];
        uint256 amountInBase = 1 ether;
        uint256 price = 100 ether;

        vm.warp(block.timestamp + 1 days);
        uint32 cancelTimestamp = uint32(block.timestamp - 12 hours); // Expired timestamp

        setupTokens(Side.BUY, user, amountInBase, price, true);

        // Prepare arguments with expired cancelTimestamp
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price,
            cancelTimestamp: cancelTimestamp, // Expired
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
        });

        vm.expectRevert(CLOB.OrderExpired.selector);
        vm.startPrank(user);

        clob.postLimitOrder(user, args);
        vm.stopPrank();
    }

    // @todo
    // /// @dev Test that an ask limit too small to get added to book after matching doesnt't cost the user the dust
    // function test_PostLimitOrder_MatchAsk_NOOPLimit() public {
    //     revert("unimplemented");
    // }
    // /// @dev Test that a bid limit too small to get added to book after matching doesn't cost the user the dust
    // function test_PostLimitOrder_MatchBid_NOOPLimit() public {
    //     revert("unimplemented");
    // }

    /// @dev Test posting a limit order with the minimum order amount (should be filled)
    function testFuzz_PostLimitOrder_MatchBid_Account(uint128 amountInBase, uint128 matchedBase, uint256 price)
        public
    {
        price = bound(price, TICK_SIZE, 100_000 ether);
        price -= price % TICK_SIZE;
        _assumeLimitOrderParams(amountInBase, matchedBase);
        testPostLimitOrder_MatchBid_Helper(amountInBase, matchedBase, price);
    }

    function testFuzz_PostLimitOrder_MatchAsk_Account(uint128 amountInBase, uint128 matchedBase, uint256 price)
        public
    {
        price = bound(price, TICK_SIZE, 100_000 ether);
        price -= price % TICK_SIZE;
        _assumeLimitOrderParams(amountInBase, matchedBase);
        testPostLimitOrder_MatchAsk_Helper(amountInBase, matchedBase, price);
    }

    function testPostLimitOrder_MatchBid_Helper(
        uint128 amountInBase,
        uint128 matchedBase,
        uint256 price
    ) internal {
        address taker = users[0];
        address maker = users[1];

        if (matchedBase > 0) setupOrder(Side.SELL, maker, matchedBase, price);

        setupTokens(Side.BUY, taker, amountInBase, price, true);

        uint256 balBefore = clobManager.accountManager().getAccountBalance(taker, address(quoteToken));

        // Submit user's order to match with
        vm.prank(taker);
        ICLOB.PostLimitOrderResult memory result = clob.postLimitOrder(
            taker,
            ICLOB.PostLimitOrderArgs({
                amountInBase: amountInBase,
                clientOrderId: 0,
                price: price,
                cancelTimestamp: NEVER,
                side: Side.BUY,
                limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
            })
        );

        MatchQuantities memory matchQuantities =
            computeMatchQuantities(Side.BUY, amountInBase, matchedBase, price, taker, maker, true);

        // Verify results
        assertEq(result.orderId, matchedBase == 0 ? 1 : 2, "Order ID should increment");
        // If the order was partially filled, the amount posted should match as long as it's above the minimum
        assertEq(
            result.amountPostedInBase,
            matchQuantities.postedQuoteInBase >= MIN_LIMIT_ORDER_AMOUNT_IN_BASE ? matchQuantities.postedQuoteInBase : 0,
            "Amount posted should match"
        );
        assertEq(
            result.quoteTokenAmountTraded,
            -int256(matchQuantities.matchedQuote),
            "Quote token amount traded should match"
        );
        assertEq(
            result.baseTokenAmountTraded, int256(matchQuantities.matchedBase), "Base token amount traded should match"
        );

        assertEq(result.takerFee, matchQuantities.takerFeeInBase, "Taker fee should match");

        uint256 expectedQuoteTokenBalance =
            balBefore - uint256(-result.quoteTokenAmountTraded) - quoteTokenAmount(price, result.amountPostedInBase);
        assertTokenBalance(taker, Side.BUY, matchQuantities.matchedBase - matchQuantities.takerFeeInBase);
        assertTokenBalance(taker, Side.SELL, expectedQuoteTokenBalance);
        assertTokenBalance(maker, Side.BUY, 0);
        assertTokenBalance(maker, Side.SELL, matchQuantities.matchedQuote - matchQuantities.makerFeeInQuote);
    }

    function testPostLimitOrder_MatchAsk_Helper(
        uint128 amountInBase,
        uint128 matchedBase,
        uint256 price
    ) internal {
        address taker = users[0];
        address maker = users[1];

        if (matchedBase > 0) setupOrder(Side.BUY, maker, matchedBase, price);

        setupTokens(Side.SELL, taker, amountInBase, price, true);

        // Submit user's order to match with
        vm.prank(taker);
        ICLOB.PostLimitOrderResult memory result = clob.postLimitOrder(
            taker,
            ICLOB.PostLimitOrderArgs({
                amountInBase: amountInBase,
                clientOrderId: 0,
                price: price,
                cancelTimestamp: NEVER,
                side: Side.SELL,
                limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
            })
        );

        MatchQuantities memory matchQuantities =
            computeMatchQuantities(Side.SELL, amountInBase, matchedBase, price, taker, maker, true);

        // Verify results
        assertEq(result.orderId, matchedBase == 0 ? 1 : 2, "Order ID should increment");
        // If the order was partially filled, the amount posted should match as long as it's above the minimum
        assertEq(
            result.amountPostedInBase,
            matchQuantities.postedBase >= MIN_LIMIT_ORDER_AMOUNT_IN_BASE ? matchQuantities.postedBase : 0,
            "Amount posted should match"
        );
        assertEq(
            result.quoteTokenAmountTraded,
            int256(matchQuantities.matchedQuote),
            "Quote token amount traded should match"
        );
        assertEq(
            result.baseTokenAmountTraded, -int256(matchQuantities.matchedBase), "Base token amount traded should match"
        );

        assertEq(result.takerFee, matchQuantities.takerFeeInQuote, "Taker fee should match");

        // All base tokens should have been spent UNLESS the order was partially filled
        // and could not post the difference due to min order constraints.
        assertTokenBalance(
            taker,
            Side.BUY,
            matchQuantities.postedBase >= MIN_LIMIT_ORDER_AMOUNT_IN_BASE ? 0 : matchQuantities.postedBase
        );

        assertTokenBalance(taker, Side.SELL, matchQuantities.matchedQuote - matchQuantities.takerFeeInQuote);
        assertTokenBalance(maker, Side.BUY, matchedBase - matchQuantities.makerFeeInBase);
        assertTokenBalance(maker, Side.SELL, 0);
    }

    function testPostLimitOrder_ZeroCostTrade(uint256) public {
        address maker = users[0];
        address taker = users[1];
        uint256 amount = 100;
        uint256 price = 1;
        Side makerSide = _random() % 2 == 0 ? Side.BUY : Side.SELL;
        Side takerSide = makerSide == Side.BUY ? Side.SELL : Side.BUY;

        vm.startPrank(address(clobManager));
        clob.setMinLimitOrderAmountInBase(amount);
        clob.setTickSize(price);
        vm.stopPrank();

        setupOrder(makerSide, maker, 1 ether, price);
        setupTokens(takerSide, taker, amount, price, true);

        ICLOB.PostLimitOrderArgs memory fillArgs = ICLOB.PostLimitOrderArgs({
                amountInBase: amount,
                clientOrderId: 0,
                price: price,
                cancelTimestamp: NEVER,
                side: takerSide,
                limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED

            });

        // this should trigger ZeroTrade due to no trades present in the orderbook at all
        vm.expectRevert(CLOB.ZeroCostTrade.selector);
        vm.prank(taker);
        clob.postLimitOrder(taker, fillArgs);
    }

    function _assumeLimitOrderParams(uint256 amountInBase, uint256 matchedBase) internal pure {
        bool amountInBaseIsAboveMin = amountInBase >= MIN_LIMIT_ORDER_AMOUNT_IN_BASE;
        bool matchedBaseValid =
            matchedBase <= amountInBase && (matchedBase >= MIN_LIMIT_ORDER_AMOUNT_IN_BASE || matchedBase == 0);
        vm.assume(amountInBaseIsAboveMin && matchedBaseValid);
    }

    function test_PostLimitOrder_LimitsPlacedExceedsMax_ExpectRevert() public {
        // Create a new user that is not max limit exempt
        address user = makeAddr("nonExemptUser");
        uint256 amountInBase = 1 ether;
        uint256 price = 100 ether;

        // Set maxLimitsPerTx to 1 for easier testing
        vm.prank(address(clobManager));
        clob.setMaxLimitsPerTx(1);

        // Setup tokens for 2 orders (1 allowed + 1 that will fail)
        uint256 quoteAmount = quoteTokenAmount(amountInBase, price);
        setupTokens(Side.BUY, user, quoteAmount * 2, price, true);

        vm.startPrank(user);

        // Post the first order (should succeed)
        ICLOB.PostLimitOrderArgs memory firstOrder = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price,
            cancelTimestamp: NEVER,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
        });

        clob.postLimitOrder(user, firstOrder);

        // Attempt to post second order in the same transaction (should fail)
        ICLOB.PostLimitOrderArgs memory secondOrder = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price + TICK_SIZE, // Different price to avoid matching
            cancelTimestamp: NEVER,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
        });

        // Expect revert due to exceeding max limits per transaction
        vm.expectRevert(BookLib.LimitsPlacedExceedsMax.selector);
        clob.postLimitOrder(user, secondOrder);

        vm.stopPrank();
    }

    /// @dev tests that max limit exempt external call only happens once
    function test_PostLimitOrder_MaxLimitExemptCaching() public {
        address user = users[0]; // This user is max limit exempt
        uint256 amountInBase = 1 ether;
        uint256 price = 100 ether;

        // Set maxLimitsPerTx to 1 for easier testing
        vm.prank(address(clobManager));
        clob.setMaxLimitsPerTx(1);

        // Setup tokens for 3 orders
        uint256 quoteAmount = quoteTokenAmount(amountInBase, price);
        setupTokens(Side.BUY, user, quoteAmount * 3, price, true);

        // exemption call shiuld only happen once
        vm.expectCall(address(clobManager), abi.encodeCall(clobManager.getMaxLimitExempt, (user)), 1);

        vm.startPrank(user);

        ICLOB.PostLimitOrderArgs memory firstOrder = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price,
            cancelTimestamp: NEVER,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
        });

        // First order hits max limits
        clob.postLimitOrder(user, firstOrder);

        ICLOB.PostLimitOrderArgs memory secondOrder = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price + TICK_SIZE,
            cancelTimestamp: NEVER,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
        });

        // Second order results in a exemption list call
        clob.postLimitOrder(user, secondOrder);


        ICLOB.PostLimitOrderArgs memory thirdOrder = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price + (2 * TICK_SIZE),
            cancelTimestamp: NEVER,
            side: Side.BUY,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
        });

        // third order does not perform external exemption call
        clob.postLimitOrder(user, thirdOrder);

        vm.stopPrank();

        // Verify all 3 orders were actually posted so its not a false positive
        assertTrue(clob.getOrder(1).owner == user, "First order should exist");
        assertTrue(clob.getOrder(2).owner == user, "Second order should exist");
        assertTrue(clob.getOrder(3).owner == user, "Third order should exist");
    }
}
