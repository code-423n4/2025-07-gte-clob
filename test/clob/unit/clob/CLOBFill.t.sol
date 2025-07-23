// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {TestPlus} from "lib/solady/test/utils/TestPlus.sol";
import {CLOBTestBase, MatchQuantities} from "test/clob/utils/CLOBTestBase.sol";
import {ICLOB} from "contracts/clob/ICLOB.sol";
import {Side} from "contracts/clob/types/Order.sol";
import {CLOB} from "contracts/clob/CLOB.sol";
import {MarketSettings, MarketConfig} from "contracts/clob/types/Book.sol";
import "forge-std/console.sol";
contract CLOBPostFillOrderTest is CLOBTestBase, TestPlus {

    function testPostFillOrder_FOK_Success_Buy_AmountOut_Account(uint128 amountInBase, uint256 price) public {
        price = bound(price, TICK_SIZE, 100_000 ether);
        price -= price % TICK_SIZE;
        vm.assume(amountInBase >= MIN_LIMIT_ORDER_AMOUNT_IN_BASE);
        testPostFillOrder_FOK_Success_Buy_AmountOut_Helper(price, amountInBase);
    }

    function testPostFillOrder_FOK_Success_Buy_AmountIn_Account(uint128 amountInQuote, uint256 price) public {
        price = bound(price, TICK_SIZE, 100_000 ether);
        price -= price % TICK_SIZE;
        vm.assume(baseTokenAmount(price, amountInQuote) >= MIN_LIMIT_ORDER_AMOUNT_IN_BASE);
        testPostFillOrder_FOK_Success_Buy_AmountIn_Helper(price, amountInQuote);
    }

    function testPostFillOrder_FOK_Success_Sell_AmountIn_Account(uint128 amountInBase, uint256 price) public {
        price = bound(price, TICK_SIZE, 100_000 ether);
        price -= price % TICK_SIZE;
        vm.assume(amountInBase >= MIN_LIMIT_ORDER_AMOUNT_IN_BASE);
        testPostFillOrder_FOK_Success_Sell_AmountIn_Helper(amountInBase, price);
    }

    function testPostFillOrder_FOK_Success_Sell_AmountOut_Account(uint128 amountInQuote, uint256 price) public {
        price = bound(price, TICK_SIZE, 100_000 ether);
        price -= price % TICK_SIZE;
        vm.assume(baseTokenAmount(price, amountInQuote) >= MIN_LIMIT_ORDER_AMOUNT_IN_BASE);
        testPostFillOrder_FOK_Success_Sell_AmountOut_Helper(amountInQuote, price);
    }

    /// For benchmarking large limits
    function testPostFillOrder_FOK_LargeLimit_Success_Buy() public {
        address taker = users[0];
        address maker = users[1];
        uint256 makerAmount = 1 ether;
        uint256 price =  1 ether / 100;
        uint256 takerAmount;

        for (uint256 i = 0; i < 50; i++) {
            setupOrder(Side.SELL, maker, 1 ether, price);
            takerAmount += quoteTokenAmount(price, makerAmount);
        }

        setupTokens(Side.BUY, taker, takerAmount, price, false);

        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: takerAmount,
            priceLimit: price,
            side: Side.BUY,
            amountIsBase: false,
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        vm.prank(taker);
        clob.postFillOrder(taker, fillArgs);
    }

    /// For benchmarking large limits
    function testPostFillOrder_FOK_LargeLimit_Success_Sell() public {
        address taker = users[0];
        address maker = users[1];
        uint256 makerAmount = 1 ether;
        uint256 price =  1 ether / 100;
        uint256 takerAmount;

        for (uint256 i = 0; i < 50; i++) {
            setupOrder(Side.BUY, maker, 1 ether, price);
            takerAmount += baseTokenAmount(price, makerAmount);
        }

        setupTokens(Side.SELL, taker, takerAmount, price, true);

        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: takerAmount,
            priceLimit: price,
            side: Side.SELL,
            amountIsBase: true,
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        vm.prank(taker);
        clob.postFillOrder(taker, fillArgs);
    }
    function testPostFillOrder_FOK_Failure_Sell() public {
        address taker = users[0];
        address maker = users[1];
        uint256 amountInQuoteLimit = 1 ether;

        MarketSettings memory s = clob.getMarketSettings();
        uint256 price = s.tickSize;
        uint256 amountInBaseFill = baseTokenAmount(price, amountInQuoteLimit);

        // The limit wont have enough size to satisfy the fill
        amountInQuoteLimit -= 1;
        uint256 amountInBaseLimit = baseTokenAmount(price, amountInQuoteLimit);

        setupOrder(Side.BUY, maker, amountInBaseLimit, price);
        setupTokens(Side.SELL, taker, amountInBaseFill, price, false);

        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: amountInBaseFill,
            priceLimit: price,
            side: Side.SELL,
            amountIsBase: true,
            fillOrderType: ICLOB.FillOrderType.FILL_OR_KILL
        });

        vm.expectRevert(abi.encodeWithSelector(CLOB.FOKOrderNotFilled.selector));
        vm.prank(taker);
        clob.postFillOrder(taker, fillArgs);
    }

    function testPostFillOrder_FOK_FAILURE_Buy() public {
        address taker = users[0];
        address maker = users[1];
        uint256 amountInBaseLimit = 1 ether;

        MarketSettings memory s = clob.getMarketSettings();
        uint256 price = s.tickSize;

        uint256 amountInQuoteFill = baseTokenAmount(price, amountInBaseLimit);

        // The limit wont have enough size to satisfy the fill
        amountInBaseLimit -= 1;

        setupOrder(Side.SELL, maker, amountInBaseLimit, price);
        setupTokens(Side.BUY, taker, amountInQuoteFill, price, false);

        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: amountInQuoteFill,
            priceLimit: price,
            side: Side.BUY,
            amountIsBase: false,
            fillOrderType: ICLOB.FillOrderType.FILL_OR_KILL
        });

        vm.expectRevert(abi.encodeWithSelector(CLOB.FOKOrderNotFilled.selector));
        vm.prank(taker);
        clob.postFillOrder(taker, fillArgs);
    }

    function testPostFillOrder_EatExpiredAskOrders() public {
        address maker0 = users[0];
        address maker1 = users[1];
        address maker2 = users[2];
        address maker3 = users[3];
        address taker = users[4];

        MarketSettings memory s = clob.getMarketSettings();
        uint256 tickSize = s.tickSize;
        uint256 amountInBase = 1 ether;

        // first 2 makers are expired
        setupOrderExpiry = NOW + 1; // 2
        setupOrder(Side.SELL, maker0, amountInBase, tickSize);

        setupOrderExpiry += 1; // 3
        setupOrder(Side.SELL, maker1, amountInBase, tickSize * 2);

        setupOrderExpiry += 1; // 4
        // Set up maker2 with 1 ether (matches taker's amount)
        setupOrder(Side.SELL, maker2, amountInBase, tickSize * 3); // 1 ether at tickSize * 3

        setupOrderExpiry += 1; // 5
        // Set up maker3 with 2 ether at highest price (won't get filled)
        setupOrder(Side.SELL, maker3, amountInBase * 2, tickSize * 4); // 2 ether at tickSize * 4

        vm.warp(uint256(NOW + 3)); // Make first 2 makers expired

        // Taker buys 1 ether - this will traverse expired orders and fill maker2's order
        setupTokens(Side.BUY, taker, amountInBase, tickSize * 4, false);
        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: amountInBase,
            priceLimit: tickSize * 4,
            side: Side.BUY,
            amountIsBase: true,
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        vm.prank(taker);
        clob.postFillOrder(taker, fillArgs);

        // First 2 orders (ids 1 and 2) should both be removed after the post fill order call (expired)
        assertEq(clob.getOrder(1).owner, address(0));
        assertEq(clob.getOrder(2).owner, address(0));

        // Order 3 (maker2) should be fully filled and removed
        assertEq(clob.getOrder(3).owner, address(0));

        // Order 4 (maker3) should not have been filled
        assertEq(clob.getOrder(4).owner, maker3);
        assertEq(clob.getOrder(4).amount, amountInBase * 2); // 2 ether remaining

        // Base open interest should equal maker3's order amount
        (, uint256 baseOI) = clob.getOpenInterest();
        assertEq(baseOI, amountInBase * 2);
    }

    function testPostFillOrder_EatExpiredBidOrders() public {
        address maker0 = users[0];
        address maker1 = users[1];
        address maker2 = users[2];
        address maker3 = users[3];
        address taker = users[4];

        MarketSettings memory s = clob.getMarketSettings();
        uint256 tickSize = s.tickSize;
        uint256 amountInBase = 1 ether;

        // first 2 makers are expired
        setupOrderExpiry = NOW + 1; // 2
        setupOrder(Side.BUY, maker0, amountInBase, tickSize * 4);

        setupOrderExpiry += 1; // 3
        setupOrder(Side.BUY, maker1, amountInBase, tickSize * 3);

        setupOrderExpiry += 1; // 4
        // Set up maker2 with 1 ether (matches taker's amount)
        setupOrder(Side.BUY, maker2, amountInBase, tickSize * 2); // 1 ether at tickSize * 2

        setupOrderExpiry += 1; // 5
        // Set up maker3 with 2 ether at lowest price (won't get filled)
        setupOrder(Side.BUY, maker3, amountInBase * 2, tickSize); // 2 ether at tickSize

        vm.warp(uint256(NOW + 3)); // Make first 2 makers expired

        // Taker sells 1 ether - this will traverse expired orders and fill maker2's order
        setupTokens(Side.SELL, taker, amountInBase, tickSize, false);
        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: amountInBase,
            priceLimit: tickSize,
            side: Side.SELL,
            amountIsBase: true,
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        vm.prank(taker);
        clob.postFillOrder(taker, fillArgs);

        // First 2 orders (ids 1 and 2) should both be removed after the post fill order call (expired)
        assertEq(clob.getOrder(1).owner, address(0));
        assertEq(clob.getOrder(2).owner, address(0));

        // Order 3 (maker2) should be fully filled and removed
        assertEq(clob.getOrder(3).owner, address(0));

        // Order 4 (maker3) should not have been filled
        assertEq(clob.getOrder(4).owner, maker3);
        assertEq(clob.getOrder(4).amount, amountInBase * 2); // 2 ether remaining

        // Quote open interest should equal maker3's order amount * price
        (uint256 quoteOI, ) = clob.getOpenInterest();
        uint256 expectedQuoteOI = clob.getQuoteTokenAmount(tickSize, amountInBase * 2); // 2 ether * tickSize
        assertEq(quoteOI, expectedQuoteOI);
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /// @dev Test that a FILL_OR_KILL fill order succeeds
    function testPostFillOrder_FOK_Success_Buy_AmountOut_Helper(
        uint256 price,
        uint256 amountInBase
    ) private {
        // Simulate the order book reaching max number of orders
        address taker = users[0];
        address maker = users[1];

        setupOrder(Side.SELL, maker, amountInBase, price);
        setupTokens(Side.BUY, taker, amountInBase, price, true);

        // Fill the order from opposite side, matching complete amount
        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: amountInBase,
            priceLimit: price,
            side: Side.BUY,
            amountIsBase: true,
            fillOrderType: ICLOB.FillOrderType.FILL_OR_KILL
        });

        MatchQuantities memory matchQuantities =
            computeMatchQuantities(Side.BUY, amountInBase, amountInBase, price, taker, maker, true);

        // Expect emit fill order submitted
        vm.expectEmit(true, true, true, true);
        emit CLOB.FillOrderSubmitted(clob.getEventNonce() + 1, taker, 2, fillArgs);
        // @todo expect emit orderMatched?
        vm.expectEmit(true, true, true, true);
        emit CLOB.FillOrderProcessed(
            clob.getEventNonce() + 2,
            taker,
            2,
            -int256(matchQuantities.matchedQuote),
            int256(matchQuantities.matchedBase),
            matchQuantities.takerFeeInBase
        );

        // Post fill order
        uint256 orderId = clob.getNextOrderId();
        vm.prank(taker);
        ICLOB.PostFillOrderResult memory result = clob.postFillOrder(taker, fillArgs);

        // Verify results
        assertEq(result.orderId, orderId, "Order ID should increment");
        // @todo fix assertion to include dust rounding for fee refunds before second audit
        // review: this should be fixed now, leaving this note here in case it ever reverts
        assertEq(
            result.quoteTokenAmountTraded, -int256(matchQuantities.matchedQuote), "Quote token change should match"
        );
        assertEq(result.baseTokenAmountTraded, int256(matchQuantities.matchedBase), "Base token change should match");
        assertEq(result.takerFee, matchQuantities.takerFeeInBase, "Taker fee should match");
        // Taker should have succesfully purchased base tokens
        assertTokenBalance(taker, Side.BUY,  matchQuantities.matchedBase - matchQuantities.takerFeeInBase);
        assertTokenBalance(
            taker, Side.SELL,  quoteTokenAmount(price, amountInBase) - matchQuantities.matchedQuote
        );
        // Maker should have succesfully sold quote tokens
        assertTokenBalance(maker, Side.BUY,  0);
        assertTokenBalance(maker, Side.SELL,  matchQuantities.matchedQuote - matchQuantities.makerFeeInQuote);
    }

    function testPostFillOrder_FOK_Success_Buy_AmountIn_Helper(
        uint256 price,
        uint256 amountInQuote
    ) private {
        // Simulate the order book reaching max number of orders
        address taker = users[0];
        address maker = users[1];

        // note: we make the maker order a bit larger to account for rounding error and ensure FOK succeeds
        uint256 amountInBase = baseTokenAmount(price, amountInQuote) + 1;

        setupOrder(Side.SELL, maker, amountInBase, price);
        setupTokens(Side.BUY, taker, amountInQuote, price, false);

        // Fill the order from opposite side, matching complete amount
        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: amountInQuote,
            priceLimit: price,
            side: Side.BUY,
            amountIsBase: false,
            fillOrderType: ICLOB.FillOrderType.FILL_OR_KILL
        });

        MatchQuantities memory matchQuantities =
            computeMatchQuantities(Side.BUY, amountInQuote, amountInBase, price, taker, maker, false);

        // Expect emit fill order submitted
        vm.expectEmit(true, true, true, true);
        emit CLOB.FillOrderSubmitted(clob.getEventNonce() + 1, taker, 2, fillArgs);
        vm.expectEmit(true, true, true, true);
        emit CLOB.FillOrderProcessed(
            clob.getEventNonce() + 2,
            taker,
            2,
            -int256(matchQuantities.matchedQuote),
            int256(matchQuantities.matchedBase),
            matchQuantities.takerFeeInBase
        );

        // Post fill order
        uint256 orderId = clob.getNextOrderId();
        vm.prank(taker);
        ICLOB.PostFillOrderResult memory result = clob.postFillOrder(taker, fillArgs);

        // Verify results
        assertEq(result.orderId, orderId, "Order ID should increment");
        // review: this should be fixed, leaving this note here in case it ever reverts
        assertEq(
            result.quoteTokenAmountTraded, -int256(matchQuantities.matchedQuote), "Quote token change should match"
        );
        assertEq(result.baseTokenAmountTraded, int256(matchQuantities.matchedBase), "Base token change should match");
        assertEq(result.takerFee, matchQuantities.takerFeeInBase, "Taker fee should match");
        // Taker should have succesfully purchased base tokens
        assertTokenBalance(taker, Side.BUY,  matchQuantities.matchedBase - matchQuantities.takerFeeInBase);
        assertTokenBalance(taker, Side.SELL,  amountInQuote - matchQuantities.matchedQuote);
        // Maker should have succesfully sold quote tokens
        assertTokenBalance(maker, Side.BUY,  0);
        assertTokenBalance(maker, Side.SELL,  matchQuantities.matchedQuote - matchQuantities.makerFeeInQuote);
    }

    /// @notice Test that a FILL_OR_KILL fill order succeeds
    function testPostFillOrder_FOK_Success_Sell_AmountIn_Helper(
        uint128 amountInBase,
        uint256 price
    ) private {
        // Simulate the order book reaching max number of orders
        address taker = users[0];
        address maker = users[1];

        setupOrder(Side.BUY, maker, amountInBase, price);
        setupTokens(Side.SELL, taker, amountInBase, price, true);

        // Fill the order from opposite side, matching complete amount
        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: amountInBase,
            priceLimit: price,
            side: Side.SELL,
            amountIsBase: true,
            fillOrderType: ICLOB.FillOrderType.FILL_OR_KILL
        });

        MatchQuantities memory matchQuantities =
            computeMatchQuantities(Side.SELL, amountInBase, amountInBase, price, taker, maker, true);

        // Expect emit fill order submitted
        vm.expectEmit(true, true, true, true);
        emit CLOB.FillOrderSubmitted(clob.getEventNonce() + 1, taker, 2, fillArgs);

        // @todo expect emit orderMatched?
        vm.expectEmit(true, true, true, true);
        emit CLOB.FillOrderProcessed(
            clob.getEventNonce() + 2,
            taker,
            2,
            int256(matchQuantities.matchedQuote),
            -int256(matchQuantities.matchedBase),
            matchQuantities.takerFeeInQuote
        );

        // Post fill order
        uint256 orderId = clob.getNextOrderId();
        vm.prank(taker);
        ICLOB.PostFillOrderResult memory result = clob.postFillOrder(taker, fillArgs);

        // Verify results
        assertEq(result.orderId, orderId, "Order ID should increment");
        assertEq(result.quoteTokenAmountTraded, int256(matchQuantities.matchedQuote), "Quote token change should match");
        assertEq(result.baseTokenAmountTraded, -int256(matchQuantities.matchedBase), "Base token change should match");
        assertEq(result.takerFee, matchQuantities.takerFeeInQuote, "Taker fee should match");
        // Taker should have succesfully purchased quote tokens
        assertTokenBalance(taker, Side.BUY,  0);
        assertTokenBalance(taker, Side.SELL,  matchQuantities.matchedQuote - matchQuantities.takerFeeInQuote);
        // Maker should have succesfully sold quote tokens
        assertTokenBalance(maker, Side.BUY,  matchQuantities.matchedBase - matchQuantities.makerFeeInBase);
        assertTokenBalance(maker, Side.SELL,  0);
    }

    function testPostFillOrder_FOK_Success_Sell_AmountOut_Helper(
        uint128 amountInQuote,
        uint256 price
    ) private {
        // Simulate the order book reaching max number of orders
        address taker = users[0];
        address maker = users[1];

        // note: we make the maker order a bit larger to account for rounding error and ensure FOK succeeds
        uint256 amountInBase = baseTokenAmount(price, amountInQuote) + 1;

        setupOrder(Side.BUY, maker, amountInBase, price);
        setupTokens(Side.SELL, taker, amountInQuote, price, false);

        // Fill the order from opposite side, matching complete amount
        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: amountInQuote,
            priceLimit: price,
            side: Side.SELL,
            amountIsBase: false,
            fillOrderType: ICLOB.FillOrderType.FILL_OR_KILL
        });

        MatchQuantities memory matchQuantities =
            computeMatchQuantities(Side.SELL, amountInQuote, amountInBase, price, taker, maker, false);

        // Expect emit fill order submitted
        vm.expectEmit(true, true, true, true);
        emit CLOB.FillOrderSubmitted(clob.getEventNonce() + 1, taker, 2, fillArgs);
        // @todo expect emit orderMatched?
        vm.expectEmit(true, true, true, true);
        emit CLOB.FillOrderProcessed(
            clob.getEventNonce() + 2,
            taker,
            2,
            int256(matchQuantities.matchedQuote),
            -int256(matchQuantities.matchedBase),
            matchQuantities.takerFeeInQuote
        );

        // Post fill order
        uint256 orderId = clob.getNextOrderId();
        vm.prank(taker);
        ICLOB.PostFillOrderResult memory result = clob.postFillOrder(taker, fillArgs);

        // Verify results
        assertEq(result.orderId, orderId, "Order ID should increment");
        assertEq(result.quoteTokenAmountTraded, int256(matchQuantities.matchedQuote), "Quote token change should match");
        assertEq(result.baseTokenAmountTraded, -int256(matchQuantities.matchedBase), "Base token change should match");
        assertEq(result.takerFee, matchQuantities.takerFeeInQuote, "Taker fee should match");
        // Taker should have succesfully purchased quote tokens
        assertTokenBalance(taker, Side.BUY,  0);
        assertTokenBalance(taker, Side.SELL,  matchQuantities.matchedQuote - matchQuantities.takerFeeInQuote);
        // Maker should have succesfully sold quote tokens
        assertTokenBalance(maker, Side.BUY,  matchQuantities.matchedBase - matchQuantities.makerFeeInBase);
        assertTokenBalance(maker, Side.SELL,  0);
    }

    /*//////////////////////////////////////////////////////////////
                            LOT SIZE TESTS
    //////////////////////////////////////////////////////////////*/
    function testPostFillOrder_LotSizeTruncation_Fill_AmountBase(uint256) public {
        address taker = users[0];
        address maker = users[1];

        Side takerSide = _random() % 2 == 0 ? Side.BUY : Side.SELL;
        Side makerSide = takerSide == Side.BUY ? Side.SELL : Side.BUY;

        uint256 makerAmount = 0.751 ether; // Not a multiple of lot size
        uint256 takerAmount = 0.681 ether; // Not a multiple of lot size

        uint256 price = _hem(_random(), 1, 1000) * TICK_SIZE;
        uint256 lotSize = _hem(_random(), LOT_SIZE_IN_BASE, takerAmount);

        lotSize -= lotSize % LOT_SIZE_IN_BASE;

        setupOrder(makerSide, maker, makerAmount, price);

        vm.prank(address(clobManager));
        clob.setLotSizeInBase(lotSize); // Set specific lot size for fill

        setupTokens(takerSide, taker, takerAmount, price, true);

        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: takerAmount,
            priceLimit: price,
            side: takerSide,
            amountIsBase: true,
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        uint256 expectedFillAmount = (takerAmount / lotSize) * lotSize;

        vm.prank(taker);
        ICLOB.PostFillOrderResult memory result = clob.postFillOrder(taker, fillArgs);

        // Verify the fill was truncated to lot size multiple
        int256 baseTokenAmountTraded = takerSide == Side.BUY ? result.baseTokenAmountTraded : -result.baseTokenAmountTraded;
        assertEq(uint256(baseTokenAmountTraded), expectedFillAmount, "Base amount should be truncated to lot size multiple");
        assertGt(uint256(baseTokenAmountTraded), 0, "Should have traded some amount");
        assertLt(uint256(baseTokenAmountTraded), takerAmount, "Should have truncated the original amount");

        // Verify the maker order still has remaining size
        uint256 remainingMakerAmount = makerAmount - expectedFillAmount;
        assertEq(clob.getOrder(1).amount, remainingMakerAmount, "Maker order should have remaining amount");
    }
    function testPostFillOrder_LotSizeTruncation_Fill_AmountQuote(uint256) public {
        address taker = users[0];
        address maker = users[1];

        Side takerSide = _random() % 2 == 0 ? Side.BUY : Side.SELL;
        Side makerSide = takerSide == Side.BUY ? Side.SELL : Side.BUY;

        uint256 price = _hem(_random(), 1, 1000) * TICK_SIZE;
        uint256 makerAmount = 2 ether;
        uint256 takerQuoteAmount = 0.000556 ether;

        uint256 baseFromQuote = baseTokenAmount(price, takerQuoteAmount);
        uint256 lotSize = (LOT_SIZE_IN_BASE < baseFromQuote)
            ? _hem(_random(), LOT_SIZE_IN_BASE, baseFromQuote - 1)
            : _hem(_random(), baseFromQuote - 1, LOT_SIZE_IN_BASE);
        lotSize -= lotSize % LOT_SIZE_IN_BASE;

        vm.assume(lotSize > 0);
        vm.assume((makerAmount < baseFromQuote ? makerAmount : baseFromQuote) >= lotSize);

        setupOrder(makerSide, maker, makerAmount, price);

        vm.prank(address(clobManager));
        clob.setLotSizeInBase(lotSize); // Set specific lot size for fill

        setupTokens(takerSide, taker, takerQuoteAmount, price, false);

        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: takerQuoteAmount,
            priceLimit: price,
            side: takerSide,
            amountIsBase: false,
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        uint256 availableBase = makerAmount < baseFromQuote ? makerAmount : baseFromQuote;
        uint256 expectedFillAmount = (availableBase / lotSize) * lotSize;

        vm.prank(taker);
        ICLOB.PostFillOrderResult memory result = clob.postFillOrder(taker, fillArgs);

        // Verify the fill was truncated to lot size multiple
        int256 baseTokenAmountTraded = takerSide == Side.BUY ? result.baseTokenAmountTraded : -result.baseTokenAmountTraded;
        assertEq(uint256(baseTokenAmountTraded), expectedFillAmount, "Base amount should be truncated to lot size multiple");
        assertLe(uint256(baseTokenAmountTraded), baseFromQuote, "Should have truncated from the calculated base amount");
    }

    function testPostFillOrder_LotSizeTruncation_ZeroAmount() public {
        address taker = users[0];
        address maker = users[1];
        uint256 lotSize = 1 ether;
        uint256 price = TICK_SIZE;
        uint256 makerAmount = 2 ether;
        uint256 takerAmount = 0.5 ether; // Less than lot size, should result in zero fill

        setupOrder(Side.SELL, maker, makerAmount, price);

        vm.prank(address(clobManager));
        clob.setLotSizeInBase(lotSize); // Set specific lot size for fill

        setupTokens(Side.BUY, taker, takerAmount, price, true);

        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: takerAmount,
            priceLimit: price,
            side: Side.BUY,
            amountIsBase: true,
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        // Should revert with ZeroTrade when lot size truncation results in zero amount
        vm.expectRevert(abi.encodeWithSelector(CLOB.ZeroCostTrade.selector));
        vm.prank(taker);
        clob.postFillOrder(taker, fillArgs);

        // Maker order should remain unchanged since no trade occurred
        assertEq(clob.getOrder(1).amount, makerAmount, "Maker order should be unchanged");
    }
    function testPostFillOrder_LotSizeTruncation_MultipleOrders() public {
        address taker = users[0];
        address maker1 = users[1];
        address maker2 = users[2];
        uint256 lotSize = 0.3 ether;
        uint256 price = TICK_SIZE;
        uint256 maker1Amount = 0.5 ether;
        uint256 maker2Amount = 0.8 ether;
        uint256 takerAmount = 1.1 ether; // Should fill 0.9 ether total (3 lots)

        setupOrder(Side.SELL, maker1, maker1Amount, price);
        setupOrder(Side.SELL, maker2, maker2Amount, price);

        vm.prank(address(clobManager));
        clob.setLotSizeInBase(lotSize); // Set specific lot size for fill

        setupTokens(Side.BUY, taker, takerAmount, price, true);

        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: takerAmount,
            priceLimit: price,
            side: Side.BUY,
            amountIsBase: true,
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        vm.prank(taker);
        ICLOB.PostFillOrderResult memory result = clob.postFillOrder(taker, fillArgs);

        // Should have filled only 0.3 ether (1 lot) from the first maker
        // Lot size truncation prevents filling partial lots from individual makers
        uint256 expectedFillAmount = lotSize; // 0.3 ether (1 lot)
        assertEq(uint256(result.baseTokenAmountTraded), expectedFillAmount, "Should fill exactly 1 lot");

        // First maker should have remaining amount after partial fill
        uint256 expectedRemaining1 = maker1Amount - expectedFillAmount; // 0.5 - 0.3 = 0.2
        assertEq(clob.getOrder(1).amount, expectedRemaining1, "First maker order should have remaining amount");

        // Second maker should be unchanged since matching stopped after first maker
        assertEq(clob.getOrder(2).amount, maker2Amount, "Second maker order should be unchanged");
    }
    function testPostFillOrder_LotSizeTruncation_FOK_Failure() public {
        address taker = users[0];
        address maker = users[1];
        uint256 lotSize = 0.5 ether;
        uint256 price = TICK_SIZE;
        uint256 makerAmount = 1 ether;
        uint256 takerAmount = 0.7 ether; // Would truncate to 0.5 ether, but FOK expects exact amount

        setupOrder(Side.SELL, maker, makerAmount, price);

        vm.prank(address(clobManager));
        clob.setLotSizeInBase(lotSize); // Set specific lot size for fill

        setupTokens(Side.BUY, taker, takerAmount, price, true);

        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: takerAmount,
            priceLimit: price,
            side: Side.BUY,
            amountIsBase: true,
            fillOrderType: ICLOB.FillOrderType.FILL_OR_KILL
        });

        // FOK should fail because lot size truncation prevents filling the exact amount
        vm.expectRevert(abi.encodeWithSelector(CLOB.FOKOrderNotFilled.selector));
        vm.prank(taker);
        clob.postFillOrder(taker, fillArgs);
    }

    function testPostFillOrder_ZeroTrade_EmptyBook(uint256) public {
        address maker = users[0];
        address taker = users[1];
        uint256 amount = MIN_LIMIT_ORDER_AMOUNT_IN_BASE;
        uint256 price = TICK_SIZE;
        Side makerSide = _random() % 2 == 0 ? Side.BUY : Side.SELL;
        Side takerSide = makerSide == Side.BUY ? Side.SELL : Side.BUY;

        setupTokens(takerSide, maker, amount, price, true);

        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: amount,
            priceLimit: price,
            side: takerSide,
            amountIsBase: true,
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        // this should trigger ZeroTrade due to no trades present in the orderbook at all
        vm.expectRevert(CLOB.ZeroCostTrade.selector);
        vm.prank(taker);
        clob.postFillOrder(taker, fillArgs);
    }
    function testPostFillOrder_ZeroTrade_NoMatchingOrders(uint256) public {
        address taker = users[0];
        address maker = users[1];
        uint256 amount = MIN_LIMIT_ORDER_AMOUNT_IN_BASE;
        Side makerSide = _random() % 2 == 0 ? Side.BUY : Side.SELL;
        Side takerSide = makerSide == Side.BUY ? Side.SELL : Side.BUY;
        uint256 makerPrice = makerSide == Side.BUY ? TICK_SIZE : TICK_SIZE * 2;
        uint256 takerPrice = takerSide == Side.BUY ? TICK_SIZE : TICK_SIZE * 2;

        setupOrder(makerSide, maker, amount, makerPrice);
        setupTokens(takerSide, taker, amount, takerPrice, true);

        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: amount,
            priceLimit: takerPrice,
            side: takerSide,
            amountIsBase: true,
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        // this should trigger ZeroTrade due to no trades found at that price level
        vm.expectRevert(CLOB.ZeroCostTrade.selector);
        vm.prank(taker);
        clob.postFillOrder(taker, fillArgs);
    }

    function testPostFillOrder_ZeroCostTrade_PriceZero(uint256) public {
        address taker = users[0];
        address maker = users[1];
        uint256 amount = MIN_LIMIT_ORDER_AMOUNT_IN_BASE;
        uint256 price = TICK_SIZE;
        uint256 tinyAmount = 1;
        Side makerSide = _random() % 2 == 0 ? Side.BUY : Side.SELL;
        Side takerSide = makerSide == Side.BUY ? Side.SELL : Side.BUY;

        setupOrder(makerSide, maker, amount, price);
        setupTokens(takerSide, taker, tinyAmount, price, true);

        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: tinyAmount,
            priceLimit: price,
            side: takerSide,
            amountIsBase: true,
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        // this should trigger ZeroCostTrade due to rounding down to zero
        vm.expectRevert(CLOB.ZeroCostTrade.selector);
        vm.prank(taker);
        clob.postFillOrder(taker, fillArgs);
    }

    function testPostFillOrder_Orderbook_Swipe(uint256) public {
        address taker = users[0];
        address maker = users[1];
        uint256 amount = 1 ether;
        uint256 price = 1 ether;
        Side makerSide = _random() % 2 == 0 ? Side.BUY : Side.SELL;
        Side takerSide = makerSide == Side.BUY ? Side.SELL : Side.BUY;

        for (uint256 i = 0; i < 10; i++) {
            price = makerSide == Side.BUY ? price + i * TICK_SIZE : price - i * TICK_SIZE;
            setupOrder(makerSide, maker, amount, price);
        }

        setupTokens(takerSide, taker, amount * 11, price, true);

        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: amount * 11, // more than the orderbook has
            priceLimit: price,
            side: takerSide,
            amountIsBase: true,
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        vm.prank(taker);
        clob.postFillOrder(taker, fillArgs);
    }
    /// For benchmarking multiple different maker addresses
    function testPostFillOrder_BenchmarkMultipleMakers() public {
        address taker = users[0];
        uint256 makerAmount = 1 ether;
        uint256 price = 1 ether / 100;
        uint256 numMakers = 50;
        uint256 takerAmount;

        for (uint256 i = 0; i < numMakers; i++) {
            // Create a new maker address for each order
            address maker = vm.addr(100 + i);
            // Set max limit whitelist for the new maker
            _setMaxLimitWhitelist(maker, true);
            // Setup order with the new maker
            setupOrder(Side.SELL, maker, makerAmount, price);
            takerAmount += quoteTokenAmount(price, makerAmount);
        }

        setupTokens(Side.BUY, taker, takerAmount, price, false);

        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: takerAmount,
            priceLimit: price,
            side: Side.BUY,
            amountIsBase: false,
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        vm.prank(taker);
        clob.postFillOrder(taker, fillArgs);
    }

    /// @notice Test that dust from partial fills is properly handled with the break logic
    /// This test specifically addresses the scenario where matchedAmount == 0 due to lot size truncation
    function testPostFillOrder_LotSizeTruncation_DustHandling() public {
        address taker = users[0];
        address maker = users[1];

        // Setup a scenario where dust will be created
        uint256 lotSize = 1 ether;
        uint256 price = 1 ether; // 1 base = 1 quote
        uint256 makerAmount = 1.7 ether; // 1 full lot + 0.7 dust
        uint256 takerQuoteAmount = 2.5 ether; // Wants 2.5 base but should only get 1 lot

        // Setup maker order (selling base)
        setupOrder(Side.SELL, maker, makerAmount, price);

        // Set lot size that will cause truncation
        vm.prank(address(clobManager));
        clob.setLotSizeInBase(lotSize);

        // Setup taker tokens (quote denominated fill)
        setupTokens(Side.BUY, taker, takerQuoteAmount, price, false);

        // Create fill order (quote denominated)
        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: takerQuoteAmount,
            priceLimit: price,
            side: Side.BUY,
            amountIsBase: false, // This is key - quote denominated
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        // Execute fill order
        vm.prank(taker);
        ICLOB.PostFillOrderResult memory result = clob.postFillOrder(taker, fillArgs);

        // Verify only 1 lot was filled (no dust)
        assertEq(uint256(result.baseTokenAmountTraded), lotSize, "Should fill exactly 1 lot");
        assertEq(uint256(-result.quoteTokenAmountTraded), lotSize, "Should pay exactly 1 quote per base");

        // Verify maker order is reduced by exactly 1 lot (dust remains)
        uint256 expectedRemainingMaker = makerAmount - lotSize; // 1.7 - 1.0 = 0.7 ether
        assertEq(clob.getOrder(1).amount, expectedRemainingMaker, "Maker order should retain dust amount");

        // Verify the dust (0.7 ether) is still in the maker's order, not traded
        assertEq(clob.getOrder(1).amount, 0.7 ether, "Dust should remain in maker's order");

        // Verify taker's remaining quote tokens are still in account manager
        uint256 takerQuoteRemaining = clobManager.accountManager().getAccountBalance(taker, address(quoteToken));
        assertEq(takerQuoteRemaining, takerQuoteAmount - lotSize, "Taker should have remaining quote tokens");

        // Verify maker received quote tokens for exactly 1 lot (not including dust)
        uint256 makerQuoteReceived = clobManager.accountManager().getAccountBalance(maker, address(quoteToken));
        assertGt(makerQuoteReceived, 0, "Maker should have received quote tokens");
        assertLe(makerQuoteReceived, lotSize, "Maker should not receive more than 1 lot worth of quote");
    }

    /// @notice Test scenario where baseDelta == 0 but matchedAmount != 0 (quote-denominated case)
    /// This tests the edge case in _matchIncomingOrder where matchedAmount = takerOrder.amount
    /// even when no actual trade occurs due to lot size truncation
    function testPostFillOrder_BaseDeltaZero_MatchedAmountNonZero() public {
        address taker = users[0];
        address maker = users[1];

        // Setup: lot size larger than maker's available amount
        uint256 lotSize = 2 ether;
        uint256 price = 1 ether;
        uint256 makerAmount = 1 ether; // Less than lot size
        uint256 takerQuoteAmount = 0.5 ether; // Small quote amount

        // Setup maker order
        setupOrder(Side.SELL, maker, makerAmount, price);

        // Set large lot size
        vm.prank(address(clobManager));
        clob.setLotSizeInBase(lotSize);

        // Setup taker tokens (quote denominated)
        setupTokens(Side.BUY, taker, takerQuoteAmount, price, false);

        // Create quote-denominated fill order
        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: takerQuoteAmount,
            priceLimit: price,
            side: Side.BUY,
            amountIsBase: false, // Quote denominated - this is key
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        // This should revert with ZeroCostTrade because baseDelta == 0 (no lots can be filled)
        // but internally matchedAmount would be takerOrder.amount if not for the break logic
        vm.expectRevert(CLOB.ZeroCostTrade.selector);
        vm.prank(taker);
        clob.postFillOrder(taker, fillArgs);

        // Verify maker order is unchanged (no trade occurred)
        assertEq(clob.getOrder(1).amount, makerAmount, "Maker order should be unchanged");

        // Verify taker's quote tokens remain in account manager
        uint256 takerQuoteInAccount = clobManager.accountManager().getAccountBalance(taker, address(quoteToken));
        assertEq(takerQuoteInAccount, takerQuoteAmount, "Taker quote should remain in account");
    }

    /// @notice Test that one maker gets fully filled while the second maker's dust is ignored
    /// This verifies the break logic works correctly without causing ZeroCostTrade revert
    function testPostFillOrder_OneMakerFilled_SecondMakerDustIgnored() public {
        address taker = users[0];
        address maker1 = users[1];
        address maker2 = users[2];

        // Setup: First maker has enough for full lot, second maker has dust
        uint256 lotSize = 1 ether;
        uint256 price = 1 ether;
        uint256 maker1Amount = 1.5 ether; // 1 lot + 0.5 dust
        uint256 maker2Amount = 0.3 ether; // Only dust (less than 1 lot)
        uint256 takerQuoteAmount = 2 ether; // Wants 2 base tokens

        // Setup both maker orders at same price
        setupOrder(Side.SELL, maker1, maker1Amount, price);
        setupOrder(Side.SELL, maker2, maker2Amount, price);

        // Set lot size
        vm.prank(address(clobManager));
        clob.setLotSizeInBase(lotSize);

        // Setup taker tokens (quote denominated)
        setupTokens(Side.BUY, taker, takerQuoteAmount, price, false);

        // Create quote-denominated fill order
        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: takerQuoteAmount,
            priceLimit: price,
            side: Side.BUY,
            amountIsBase: false, // Quote denominated
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        // Execute fill order - should NOT revert
        vm.prank(taker);
        ICLOB.PostFillOrderResult memory result = clob.postFillOrder(taker, fillArgs);

        // Should have filled exactly 1 lot from maker1 only
        assertEq(uint256(result.baseTokenAmountTraded), lotSize, "Should fill exactly 1 lot");
        assertEq(uint256(-result.quoteTokenAmountTraded), lotSize, "Should pay exactly 1 quote per base");

        // Verify maker1 order was reduced by 1 lot (dust remains)
        uint256 expectedRemaining1 = maker1Amount - lotSize; // 1.5 - 1.0 = 0.5
        assertEq(clob.getOrder(1).amount, expectedRemaining1, "Maker1 order should be reduced by 1 lot");

        // Verify maker2 order is completely unchanged (dust ignored due to break)
        assertEq(clob.getOrder(2).amount, maker2Amount, "Maker2 order should be unchanged");

        // Verify only maker1 received quote tokens (maker2 didn't participate)
        assertGt(clobManager.accountManager().getAccountBalance(maker1, address(quoteToken)), 0, "Maker1 should have received quote tokens");
        assertEq(clobManager.accountManager().getAccountBalance(maker2, address(quoteToken)), 0, "Maker2 should NOT have received any quote tokens");

        // Verify taker received exactly 1 lot of base tokens (no dust)
        assertGt(clobManager.accountManager().getAccountBalance(taker, address(baseToken)), 0, "Taker should have received base tokens");
        assertLe(clobManager.accountManager().getAccountBalance(taker, address(baseToken)), lotSize, "Taker should not receive more than 1 lot");

        // Verify taker has remaining quote tokens (didn't spend on dust)
        assertEq(clobManager.accountManager().getAccountBalance(taker, address(quoteToken)), takerQuoteAmount - lotSize, "Taker should have remaining quote tokens");

        // Verify the dust amounts are preserved in both maker orders
        assertEq(clob.getOrder(1).amount, 0.5 ether, "Maker1 dust should remain");
        assertEq(clob.getOrder(2).amount, 0.3 ether, "Maker2 dust should remain");
    }

    function testPostFillOrder_PartialFillLeavingDust_ShouldNotExist() public {
        address taker = users[0];
        address maker = users[1];

        uint256 lotSize = 1;
        uint256 price = 1 ether;

        // Create a maker SELL order
        uint256 makerAmount = MIN_LIMIT_ORDER_AMOUNT_IN_BASE; // 0.005 ether
        setupOrder(Side.SELL, maker, makerAmount, price);

        // Verify initial order state
        assertEq(clob.getOrder(1).amount, makerAmount, "Maker order should exist with full amount");

        // Partially fill the maker order
        uint256 takerAmount = makerAmount - 100; // Leave 100 wei
        setupTokens(Side.BUY, taker, takerAmount, price, true);

        ICLOB.PostFillOrderArgs memory fillArgs = ICLOB.PostFillOrderArgs({
            amount: takerAmount,
            priceLimit: price,
            side: Side.BUY,
            amountIsBase: true,
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        vm.prank(taker);
        clob.postFillOrder(taker, fillArgs);

        // Check if maker order still exists
        uint256 remainingAmount = clob.getOrder(1).amount;
        uint256 expectedRemaining = 100; // 100 wei (100 lots since lotSize = 1)

        // With lot size = 1, the remaining 100 wei is actually 100 lots, not dust
        // The order should still exist and be fillable
        assertEq(remainingAmount, expectedRemaining, "Maker order should have remaining amount");

        // Verify the remaining amount is fillable (not dust)
        address taker2 = users[2];
        setupTokens(Side.BUY, taker2, remainingAmount, price, true);

        ICLOB.PostFillOrderArgs memory fillArgs2 = ICLOB.PostFillOrderArgs({
            amount: remainingAmount,
            priceLimit: price,
            side: Side.BUY,
            amountIsBase: true,
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        vm.prank(taker2);
        ICLOB.PostFillOrderResult memory result2 = clob.postFillOrder(taker2, fillArgs2);

        // The remaining amount should be fillable
        assertEq(uint256(result2.baseTokenAmountTraded), remainingAmount, "Remaining amount should be fillable");

        // Now the order should be removed (fully filled)
        assertEq(clob.getOrder(1).amount, 0, "Order should be removed after full fill");
    }
}
