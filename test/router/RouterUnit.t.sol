// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./utils/RouterTestBase.t.sol";
import {ERC20} from "solady/tokens/ERC20.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {TestPlus} from "lib/solady/test/utils/TestPlus.sol";
import {IAccountManager} from "contracts/account-manager/IAccountManager.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

contract RouterUnitTest is RouterTestBase, TestPlus {
    using FixedPointMathLib for uint256;
    using SafeTransferLib for address;

    function setUp() public override {
        super.setUp();

        deal(jb, 100_000_000 ether);
        weth.mint(jb, 100_000_000 ether);
        tokenA.mint(jb, 1000 ether);
        tokenB.mint(jb, 1000 ether);
        tokenC.mint(jb, 1000 ether);
        tokenD.mint(jb, 1000 ether);

        vm.startPrank(jb);
        tokenA.approve(address(clobManager.accountManager()), type(uint256).max);
        tokenB.approve(address(clobManager.accountManager()), type(uint256).max);
        tokenC.approve(address(clobManager.accountManager()), type(uint256).max);
        tokenD.approve(address(clobManager.accountManager()), type(uint256).max);
        tokenA.approve(address(router), type(uint256).max);
        tokenB.approve(address(router), type(uint256).max);
        tokenC.approve(address(router), type(uint256).max);
        tokenD.approve(address(router), type(uint256).max);
        weth.approve(address(clobManager.accountManager()), type(uint256).max);
        vm.stopPrank();
    }

    struct Outcome {
        address tokenIn;
        address tokenOut;
        uint256 amountIn;
        uint256 amountOut;
    }

    Outcome outcome;

    bytes[] hops;

    address[] routePath;
    uint256[] clobPrices;
    address[] uniTokenOut;

    receive() external payable {}

    function test_ClobDeposit(address who, uint256 amount, bool fromRouter) public {
        vm.assume(who != address(0) && who.code.length == 0);

        deal(address(tokenA), who, amount);

        vm.startPrank(who);

        if (fromRouter) tokenA.approve(address(router), amount);
        else tokenA.approve(address(clobManager.accountManager()), amount);

        router.spotDeposit(address(tokenA), amount, fromRouter);

        assertEq(clobManager.accountManager().getAccountBalance(who, address(tokenA)), amount, "Invalid manager balance");
        assertEq(tokenA.balanceOf(who), 0, "Invalid token balance");
    }

    function test_ClobWithdraw(address who, uint256 amount) public {
        vm.assume(who != address(0));

        deal(address(tokenA), who, amount);

        vm.startPrank(who);
        tokenA.approve(address(clobManager.accountManager()), amount);
        router.spotDeposit(address(tokenA), amount, false);

        assertEq(clobManager.accountManager().getAccountBalance(who, address(tokenA)), amount, "Invalid manager balance");

        router.spotWithdraw(address(tokenA), amount);

        assertEq(clobManager.accountManager().getAccountBalance(who, address(tokenA)), 0, "Invalid manager balance");
        assertEq(tokenA.balanceOf(who), amount);
    }

    function test_SpotDepositPermit2() public {
        uint160 amount = 1000 ether;
        uint48 expiration = uint48(block.timestamp + 1000);
        uint48 nonce = 0;

        deal(address(tokenA), jb, amount);

        vm.startPrank(jb);
        tokenA.approve(address(permit2), type(uint256).max);

        IAllowanceTransfer.PermitSingle memory permitSingle = _defaultERC20PermitAllowance(
            address(tokenA),
            amount,
            expiration,
            nonce
        );

        bytes memory signature = _getPermitSignature(
            permitSingle,
            jbKey,
            permit2.DOMAIN_SEPARATOR()
        );

        uint256 balanceBefore = clobManager.accountManager().getAccountBalance(jb, address(tokenA));
        uint256 tokenBalanceBefore = tokenA.balanceOf(jb);

        router.spotDepositPermit2(address(tokenA), amount, permitSingle, signature);

        uint256 balanceAfter = clobManager.accountManager().getAccountBalance(jb, address(tokenA));
        uint256 tokenBalanceAfter = tokenA.balanceOf(jb);

        assertEq(balanceAfter - balanceBefore, amount, "Account balance should increase by deposit amount");
        assertEq(tokenBalanceBefore - tokenBalanceAfter, amount, "Token balance should decrease by deposit amount");
        assertEq(tokenA.balanceOf(address(router)), 0, "Router should not hold tokens after deposit");

        vm.stopPrank();
    }

    function test_WrapSpotDeposit() public {
        uint256 ethAmount = 5 ether;

        vm.deal(jb, ethAmount);

        vm.startPrank(jb);

        uint256 wethAccountBalanceBefore = clobManager.accountManager().getAccountBalance(jb, address(weth));
        uint256 ethBalanceBefore = jb.balance;
        uint256 wethBalanceBefore = weth.balanceOf(jb);

        router.wrapSpotDeposit{value: ethAmount}();

        uint256 wethAccountBalanceAfter = clobManager.accountManager().getAccountBalance(jb, address(weth));
        uint256 ethBalanceAfter = jb.balance;
        uint256 wethBalanceAfter = weth.balanceOf(jb);

        assertEq(wethAccountBalanceAfter - wethAccountBalanceBefore, ethAmount, "WETH account balance should increase by ETH amount");
        assertEq(ethBalanceBefore - ethBalanceAfter, ethAmount, "ETH balance should decrease by sent amount");
        assertEq(wethBalanceAfter, wethBalanceBefore, "User WETH balance should remain unchanged");
        assertEq(weth.balanceOf(address(router)), 0, "Router should not hold WETH after deposit");

        vm.stopPrank();
    }

    function test_InvalidCLOB_ExpectRevert(address clob) public {
        vm.assume(clob.code.length == 0 && clob != address(0));

        vm.startPrank(jb);

        ICLOB.CancelArgs memory cancel;
        vm.expectRevert(abi.encodeWithSelector(GTERouter.InvalidCLOBAddress.selector));
        router.clobCancel(ICLOB(clob), cancel);

        ICLOB.PostLimitOrderArgs memory post;
        vm.expectRevert(abi.encodeWithSelector(GTERouter.InvalidCLOBAddress.selector));
        router.clobPostLimitOrder(ICLOB(clob), post);

        GTERouter.ClobHopArgs memory hopArgs = GTERouter.ClobHopArgs({
            hopType: GTERouter.HopType.CLOB_FILL,
            tokenOut: address(tokenA) // dummy token for invalid clob test
        });
        bytes memory newHop = bytes.concat(abi.encodePacked(uint8(GTERouter.HopType.CLOB_FILL)), abi.encode(hopArgs));

        hops.push(newHop);

        vm.expectRevert(abi.encodeWithSelector(GTERouter.CLOBDoesNotExist.selector));
        router.executeRoute(address(tokenA), 3 ether, 4 ether, block.timestamp + 1, hops);
    }

    function test_launchpadBuy() public {
        vm.deal(address(this), launchpad.launchFee());
        address token = launchpad.launch{value: launchpad.launchFee()}("test token", "tt", "");

        deal(address(USDC), address(this), 80_000e18);
        address(USDC).safeApprove(address(launchpad), 80_000e18);
        USDC.approve(address(router), 80_000e18);

        uint256 tokenAmount = launchpad.BONDING_SUPPLY();
        router.launchpadBuy(token, launchpad.BONDING_SUPPLY(), address(USDC), 80_000e18);

        assertEq(ERC20Harness(token).balanceOf(address(this)), tokenAmount, "did not receive tokens after buy");
    }

    // This will cause a transferFromFailed for now
    // function test_LaunchpadBuy_WrongQuoteAsset() public {}

    function test_QuoteToQuoteToAMM_Instant() public {
        uint256 price1 = 10 ether;
        uint256 price2 = 11 ether;

        outcome.amountIn = 50 ether;
        outcome.tokenIn = address(tokenA);

        routePath.push(abCLOB); // a - b
        routePath.push(bcCLOB); // b - c
        routePath.push(address(0)); // uni router c - d

        clobPrices.push(price1);
        clobPrices.push(price2);
        uniTokenOut.push(address(tokenD));

        _buildRoute(outcome.tokenIn, outcome.amountIn);

        vm.startPrank(jb);

        outcome.tokenIn.safeApprove(address(router), outcome.amountIn);
        router.spotDeposit(outcome.tokenIn, outcome.amountIn, true);

        // Get account balances after deposit but before executeRoute
        uint256 tokenInAccountBalBefore = clobManager.accountManager().getAccountBalance(jb, outcome.tokenIn);
        uint256 tokenOutAccountBalBefore = clobManager.accountManager().getAccountBalance(jb, outcome.tokenOut);

        router.executeRoute(outcome.tokenIn, outcome.amountIn, outcome.amountOut, block.timestamp + 1, hops);

        uint256 tokenInBalAfter = clobManager.accountManager().getAccountBalance(jb, outcome.tokenIn);
        uint256 tokenOutBalAfter = clobManager.accountManager().getAccountBalance(jb, outcome.tokenOut);

        assertEq(tokenOutBalAfter - tokenOutAccountBalBefore, outcome.amountOut);
        assertEq(tokenInAccountBalBefore - tokenInBalAfter, outcome.amountIn);
        assertEq(outcome.tokenOut, address(tokenD));
    }

    function test_BaseToQuoteToAMM_Instant() public {
        uint256 price1 = 10 ether;
        uint256 price2 = 11 ether;

        outcome.amountIn = 50 ether;
        outcome.tokenIn = address(tokenB);

        routePath.push(abCLOB); // b - a
        routePath.push(acCLOB); // a - c
        routePath.push(address(0)); // uni router c - d

        clobPrices.push(price1);
        clobPrices.push(price2);
        uniTokenOut.push(address(tokenD));

        _buildRoute(outcome.tokenIn, outcome.amountIn);

        uint256 tokenInBalBefore = ERC20Harness(outcome.tokenIn).balanceOf(jb);
        uint256 tokenOutBalBefore = ERC20Harness(outcome.tokenOut).balanceOf(jb);

        vm.startPrank(jb);

        outcome.tokenIn.safeApprove(address(router), outcome.amountIn);
        router.spotDeposit(outcome.tokenIn, outcome.amountIn, true);

        // Get account balances after deposit but before executeRoute
        uint256 tokenInAccountBalBefore = clobManager.accountManager().getAccountBalance(jb, outcome.tokenIn);
        uint256 tokenOutAccountBalBefore = clobManager.accountManager().getAccountBalance(jb, outcome.tokenOut);

        router.executeRoute(outcome.tokenIn, outcome.amountIn, outcome.amountOut, block.timestamp + 1, hops);

        uint256 tokenInBalAfter = clobManager.accountManager().getAccountBalance(jb, outcome.tokenIn);
        uint256 tokenOutBalAfter = clobManager.accountManager().getAccountBalance(jb, outcome.tokenOut);

        assertEq(tokenOutBalAfter - tokenOutAccountBalBefore, outcome.amountOut);
        assertEq(tokenInAccountBalBefore - tokenInBalAfter, outcome.amountIn);
        assertEq(outcome.tokenOut, address(tokenD));
    }

    function test_BaseToBaseToAMM_Instant() public {
        uint256 price1 = 10 ether;
        uint256 price2 = 11 ether;

        outcome.amountIn = 50 ether;
        outcome.tokenIn = address(tokenC);

        routePath.push(bcCLOB); // c - b
        routePath.push(abCLOB); // b - a
        routePath.push(address(0)); // uni router a - d

        clobPrices.push(price1);
        clobPrices.push(price2);
        uniTokenOut.push(address(tokenD));

        _buildRoute(outcome.tokenIn, outcome.amountIn);

        vm.startPrank(jb);

        outcome.tokenIn.safeApprove(address(router), outcome.amountIn);
        router.spotDeposit(outcome.tokenIn, outcome.amountIn, true);

        // Get account balances after deposit but before executeRoute
        uint256 tokenInAccountBalBefore = clobManager.accountManager().getAccountBalance(jb, outcome.tokenIn);
        uint256 tokenOutAccountBalBefore = clobManager.accountManager().getAccountBalance(jb, outcome.tokenOut);

        router.executeRoute(outcome.tokenIn, outcome.amountIn, outcome.amountOut, block.timestamp + 1, hops);

        uint256 tokenInBalAfter = clobManager.accountManager().getAccountBalance(jb, outcome.tokenIn);
        uint256 tokenOutBalAfter = clobManager.accountManager().getAccountBalance(jb, outcome.tokenOut);

        assertEq(tokenOutBalAfter - tokenOutAccountBalBefore, outcome.amountOut);
        assertEq(tokenInAccountBalBefore - tokenInBalAfter, outcome.amountIn);
        assertEq(outcome.tokenOut, address(tokenD));
    }

    function test_AMMToBaseToBase() public {
        uint256 price1 = 10 ether;
        uint256 price2 = 11 ether;

        outcome.amountIn = 50 ether;
        outcome.tokenIn = address(tokenD);

        routePath.push(address(0)); // uni router d - c
        routePath.push(bcCLOB); // c - b
        routePath.push(abCLOB); // b - a

        clobPrices.push(price1);
        clobPrices.push(price2);
        uniTokenOut.push(address(tokenC));

        _buildRoute(outcome.tokenIn, outcome.amountIn);

        vm.startPrank(jb);

        outcome.tokenIn.safeApprove(address(router), outcome.amountIn);
        router.spotDeposit(outcome.tokenIn, outcome.amountIn, true);

        // Get account balances after deposit but before executeRoute
        uint256 tokenInAccountBalBefore = clobManager.accountManager().getAccountBalance(jb, outcome.tokenIn);
        uint256 tokenOutAccountBalBefore = clobManager.accountManager().getAccountBalance(jb, outcome.tokenOut);

        router.executeRoute(outcome.tokenIn, outcome.amountIn, outcome.amountOut, block.timestamp + 1, hops);

        uint256 tokenInAccountBalAfter = clobManager.accountManager().getAccountBalance(jb, outcome.tokenIn);
        uint256 tokenOutAccountBalAfter = clobManager.accountManager().getAccountBalance(jb, outcome.tokenOut);

        assertEq(tokenOutAccountBalAfter - tokenOutAccountBalBefore, outcome.amountOut);
        assertEq(tokenInAccountBalBefore - tokenInAccountBalAfter, outcome.amountIn);
        assertEq(outcome.tokenOut, address(tokenA));
    }

    function test_BaseToAMMToBase() public {
        uint256 price1 = 10 ether;
        uint256 price2 = 11 ether;

        outcome.amountIn = 50 ether;
        outcome.tokenIn = address(tokenB);

        routePath.push(abCLOB); // b - a
        routePath.push(address(0)); // uni router a - c
        routePath.push(dcCLOB); // c - d

        clobPrices.push(price1);
        clobPrices.push(price2);
        uniTokenOut.push(address(tokenC));

        _buildRoute(outcome.tokenIn, outcome.amountIn);

        uint256 tokenInBalBefore = ERC20Harness(outcome.tokenIn).balanceOf(jb);
        uint256 tokenOutBalBefore = ERC20Harness(outcome.tokenOut).balanceOf(jb);

        vm.startPrank(jb);

        outcome.tokenIn.safeApprove(address(router), outcome.amountIn);
        router.spotDeposit(outcome.tokenIn, outcome.amountIn, true);

        // Get account balances after deposit but before executeRoute
        uint256 tokenInAccountBalBefore = clobManager.accountManager().getAccountBalance(jb, outcome.tokenIn);
        uint256 tokenOutAccountBalBefore = clobManager.accountManager().getAccountBalance(jb, outcome.tokenOut);

        router.executeRoute(outcome.tokenIn, outcome.amountIn, outcome.amountOut, block.timestamp + 1, hops);

        uint256 tokenInAccountBalAfter = clobManager.accountManager().getAccountBalance(jb, outcome.tokenIn);
        uint256 tokenOutAccountBalAfter = clobManager.accountManager().getAccountBalance(jb, outcome.tokenOut);

        assertEq(tokenOutAccountBalAfter - tokenOutAccountBalBefore, outcome.amountOut);
        assertEq(tokenInAccountBalBefore - tokenInAccountBalAfter, outcome.amountIn);
        assertEq(outcome.tokenOut, address(tokenD));
    }

    function _buildRoute(address tokenIn, uint256 amountIn) internal {
        for (uint256 i; i < routePath.length; ++i) {
            if (routePath[i] == address(0)) (tokenIn, amountIn) = _buildRouteUni(tokenIn, amountIn);
            else (tokenIn, amountIn) = _buildRouteCLOB(ICLOB(routePath[i]), tokenIn, amountIn);
        }

        outcome.tokenOut = tokenIn;
        outcome.amountOut = amountIn;
    }

    function test_ExecuteRoute_UnsupportedHopType_ExpectRevert(uint8 invalidHopType) public {
        vm.assume(
            invalidHopType != uint8(GTERouter.HopType.NULL) && invalidHopType != uint8(GTERouter.HopType.CLOB_FILL)
                && invalidHopType != uint8(GTERouter.HopType.UNI_V2_SWAP)
        );

        // Create hop with invalid hop type
        bytes memory invalidHop = bytes.concat(abi.encodePacked(invalidHopType), abi.encode("dummy data"));

        bytes[] memory _hops = new bytes[](1);
        _hops[0] = invalidHop;

        deal(address(USDC), address(this), 1);
        USDC.approve(address(router), 1);

        vm.expectRevert(abi.encodeWithSignature("Panic(uint256)", 0x21)); // Expect enum conversion panic
        router.executeRoute(address(USDC), 1, 0, block.timestamp, _hops);
    }

    function test_launchpadSell() public {
        vm.deal(address(this), launchpad.launchFee());
        address token = launchpad.launch{value: launchpad.launchFee()}("test token", "tt", "");

        deal(address(USDC), address(this), 80_000e18);
        USDC.approve(address(launchpad), 80_000e18);

        uint256 tokenAmount = 8 ether * 1e7;
        uint256 usdcAmount = launchpad.quoteQuoteForBase(address(token), tokenAmount, true);

        (uint256 tokenAmountActual, uint256 usdcAmountActual) = router.launchpadBuy(token, tokenAmount, address(USDC), 80_000e18);

        console.log("token actual", tokenAmountActual);

        assertEq(tokenAmountActual, tokenAmount, "token amount out wrong");
        assertEq(usdcAmountActual, usdcAmount, "usdc amount quoted wrong");

        token.safeApprove(address(launchpad), tokenAmountActual);

        router.launchpadSell(token, tokenAmount, 0);

        assertEq(USDC.balanceOf(address(this)), 80_000e18);
    }

    /// @dev 3-27 finding 3.9 The amount in of a univ2 route should be based on previous route's amount out
    function test_UniTrade_AmountInOverride() public {
        address[] memory path = new address[](2);
        path[0] = address(tokenA);
        path[1] = address(tokenB);

        uint256 amountInFirst = 10 ether;
        uint256 amountOutMin = 10 ether / 2;

        // Create hop using new UniV2HopArgs format
        GTERouter.UniV2HopArgs memory hopArgs =
            GTERouter.UniV2HopArgs({hopType: GTERouter.HopType.UNI_V2_SWAP, path: path});

        bytes memory hop1 = bytes.concat(abi.encodePacked(uint8(GTERouter.HopType.UNI_V2_SWAP)), abi.encode(hopArgs));

        bytes[] memory _hops = new bytes[](1);
        _hops[0] = hop1;

        tokenA.mint(address(this), 10 ether + 1);
        tokenA.approve(address(router), 10 ether + 1);

        router.spotDeposit(address(tokenA), amountInFirst + 1, true);

        // The swap should be with executeRoute's amountIn (amountInFirst + 1), not any encoded amount
        vm.expectCall(
            address(tokenA),
            abi.encodeWithSelector(
                ERC20.transferFrom.selector, address(router), address(uniV2Router), amountInFirst + 1
            )
        );
        router.executeRoute(address(tokenA), amountInFirst + 1, amountOutMin, block.timestamp, _hops);
    }

    function _buildRouteCLOB(ICLOB clob, address tokenIn, uint256 amountIn)
        internal
        returns (address nextToken, uint256 nextAmount)
    {
        // Determine the side based on token flow
        Side side = tokenIn == address(clob.getQuoteToken()) ? Side.BUY : Side.SELL;

        // Validate token inputs
        if (side == Side.SELL) {
            if (tokenIn == address(0)) require(address(weth) == address(clob.getBaseToken()), "ARGS: WRONG CLOB");
            else require(tokenIn == address(clob.getBaseToken()), "ARGS: WRONG CLOB");
        }

        uint256 priceLimit = clobPrices[0];

        // Determine output token and calculate expected amount
        if (side == Side.BUY) {
            nextToken = address(clob.getBaseToken());
            nextAmount = clob.getBaseTokenAmount(priceLimit, amountIn);
            nextAmount -= nextAmount.fullMulDiv(TAKER_FEE_RATE, 10_000_000);
        } else {
            nextToken = address(clob.getQuoteToken());
            nextAmount = clob.getQuoteTokenAmount(priceLimit, amountIn);
            nextAmount -= nextAmount.fullMulDiv(TAKER_FEE_RATE, 10_000_000);
        }

        // Set up counter order for testing
        _setupOrder(address(clob), side == Side.BUY ? Side.SELL : Side.BUY, rite, amountIn, priceLimit);

        _removePrice();

        // Create simplified hop using new ClobHopArgs format
        GTERouter.ClobHopArgs memory hopArgs =
            GTERouter.ClobHopArgs({hopType: GTERouter.HopType.CLOB_FILL, tokenOut: nextToken});

        bytes memory newHop = bytes.concat(abi.encodePacked(uint8(GTERouter.HopType.CLOB_FILL)), abi.encode(hopArgs));
        hops.push(newHop);
    }

    function _buildRouteUni(address tokenIn, uint256 amountIn)
        internal
        returns (address nextToken, uint256 nextAmount)
    {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = uniTokenOut[0];

        uint256 amountOut = uniV2Router.getAmountsOut(amountIn, path)[1];

        _removeToken();

        // Create simplified hop using new UniV2HopArgs format
        GTERouter.UniV2HopArgs memory hopArgs =
            GTERouter.UniV2HopArgs({hopType: GTERouter.HopType.UNI_V2_SWAP, path: path});

        bytes memory newHop = bytes.concat(abi.encodePacked(uint8(GTERouter.HopType.UNI_V2_SWAP)), abi.encode(hopArgs));

        hops.push(newHop);

        return (path[1], amountOut);
    }

    function _removeToken() internal {
        address[] memory tokens = uniTokenOut;

        uint256 newLen = tokens.length - 1;

        tokens[0] = tokens[newLen];

        assembly {
            mstore(tokens, newLen)
        }

        uniTokenOut = tokens;
    }

    function _removePrice() internal {
        uint256[] memory prices = clobPrices;

        prices[0] = prices[prices.length - 1];

        uint256 newLen = prices.length - 1;

        assembly {
            mstore(prices, newLen)
        }

        clobPrices = prices;
    }
}
