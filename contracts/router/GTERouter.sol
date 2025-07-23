// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// Local interfaces
import {IUniswapV2Router01} from "./interfaces/IUniswapV2Router01.sol";

// Internal package types
import {Side} from "contracts/clob/types/Order.sol";
import {IAccountManager, ICLOBManager} from "contracts/clob/ICLOBManager.sol";
import {ILaunchpad} from "contracts/launchpad/interfaces/ILaunchpad.sol";
import {ICLOB, MarketConfig} from "contracts/clob/ICLOB.sol";

// External interfaces
import {IAllowanceTransfer} from "@permit2/interfaces/IAllowanceTransfer.sol";

// Solady imports
import {WETH} from "@solady/tokens/WETH.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {ReentrancyGuardTransient} from "@solady/utils/ReentrancyGuardTransient.sol";

contract GTERouter is ReentrancyGuardTransient {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    using HopLib for bytes;
    using HopLib for bytes[];
    using HopLib for GTERouter.__RouteMetadata__;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev sig: 0xfb6a0297
    error UnwrapWethOnly();
    /// @dev sig: 0xa8cee301
    error CLOBDoesNotExist();
    /// @dev sig: 0x559895a3
    error DeadlineExceeded();
    /// @dev sig: 0xc9bdcc53
    error InvalidTokenRoute();
    /// @dev sig: 0xbbf38157
    error InvalidCLOBAddress();
    /// @dev sig: 0x39b4a257
    error InvalidCLOBAmountSide();
    /// @dev sig: 0x6728a9f6
    error SlippageToleranceExceeded();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 DEFINITIONS AND STATE                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    enum HopType {
        NULL,
        CLOB_FILL,
        UNI_V2_SWAP
    }

    struct ClobHopArgs {
        HopType hopType;
        address tokenOut;
    }

    struct UniV2HopArgs {
        HopType hopType;
        address[] path;
    }

    /// @dev The abi version of this impl so the indexer can handle event-changing upgrades
    uint256 public constant ABI_VERSION = 1;

    WETH public immutable weth;
    ILaunchpad public immutable launchpad;
    IAccountManager public immutable acctManager;
    ICLOBManager public immutable clobAdminPanel;
    IAllowanceTransfer public immutable permit2;
    IUniswapV2Router01 public immutable uniV2Router;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        MODIFIERS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    modifier isMarket(ICLOB clob) {
        _assertValidCLOB(address(clob));
        _;
    }

    modifier inTime(uint256 deadline) {
        if (block.timestamp > deadline) revert DeadlineExceeded();
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                       CONSTRUCTOR                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    constructor(
        address payable weth_,
        address launchpad_,
        address accountManager_,
        address clobManager_,
        address uniV2Router_,
        address permit2_
    ) {
        weth = WETH(weth_);
        launchpad = ILaunchpad(launchpad_);
        acctManager = IAccountManager(accountManager_);
        clobAdminPanel = ICLOBManager(clobManager_);
        permit2 = IAllowanceTransfer(permit2_);
        uniV2Router = IUniswapV2Router01(uniV2Router_);
    }

    fallback() external {}

    receive() external payable {}

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     PUBLIC WRITES                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice A spot deposit wrapper for multicalls
    /// @dev fromRouter lets you keep token approvals here
    function spotDeposit(address token, uint256 amount, bool fromRouter) external {
        if (fromRouter) {
            token.safeTransferFrom(msg.sender, address(this), amount);
            token.safeApprove(address(acctManager), amount);
            acctManager.depositFromRouter(msg.sender, token, amount);
        } else {
            acctManager.deposit(msg.sender, token, amount);
        }
    }

    /// @notice A spot deposit wrapper for multicalls that takes a permit signature
    function spotDepositPermit2(
        address token,
        uint160 amount,
        IAllowanceTransfer.PermitSingle calldata permitSingle,
        bytes calldata signature
    ) external {
        permit2.permit(msg.sender, permitSingle, signature);
        permit2.transferFrom(msg.sender, address(this), amount, token);
        token.safeApprove(address(acctManager), amount);
        acctManager.depositFromRouter(msg.sender, token, amount);
    }

    /// @notice Wraps raw ETH and deposits it in `AccountManager` on behalf of the user
    function wrapSpotDeposit() external payable {
        weth.deposit{value: msg.value}();
        address(weth).safeApprove(address(acctManager), msg.value);
        acctManager.depositFromRouter(msg.sender, address(weth), msg.value);
    }

    /// @notice A clob withdraw wrapper for multicalling one address
    function spotWithdraw(address token, uint256 amount) external {
        acctManager.withdraw(msg.sender, token, amount);
    }

    /// @notice A clob cancel wrapper for multicalling one address
    function clobCancel(ICLOB clob, ICLOB.CancelArgs calldata args)
        external
        isMarket(clob)
        returns (uint256 quoteRefunded, uint256 baseRefunded)
    {
        return clob.cancel(msg.sender, args);
    }

    /// @notice Amends an order on behalf of the user
    function clobAmend(ICLOB clob, ICLOB.AmendArgs calldata args)
        external
        isMarket(clob)
        returns (int256 quoteDelta, int256 baseDelta)
    {
        return clob.amend(msg.sender, args);
    }

    /// @notice A clob post limit order wrapper for multicalling one address
    function clobPostLimitOrder(ICLOB clob, ICLOB.PostLimitOrderArgs calldata args)
        external
        isMarket(clob)
        returns (ICLOB.PostLimitOrderResult memory)
    {
        return clob.postLimitOrder(msg.sender, args);
    }

    /// @notice A clob post fill order wrapper for multicalling one address
    function clobPostFillOrder(ICLOB clob, ICLOB.PostFillOrderArgs calldata args)
        external
        isMarket(clob)
        returns (ICLOB.PostFillOrderResult memory)
    {
        return clob.postFillOrder(msg.sender, args);
    }

    /// @notice A launchpad sell wrapper for multicalls
    function launchpadSell(address launchToken, uint256 amountInBase, uint256 worstAmountOutQuote)
        external
        nonReentrant
        returns (uint256 baseSpent, uint256 quoteBought)
    {
        return launchpad.sell({
            account: msg.sender,
            token: launchToken,
            recipient: msg.sender,
            amountInBase: amountInBase,
            minAmountOutQuote: worstAmountOutQuote
        });
    }

    /// @notice A launchpad buy wrapper for multicalls\
    function launchpadBuy(address launchToken, uint256 amountOutBase, address quoteToken, uint256 worstAmountInQuote)
        external
        nonReentrant
        returns (uint256 baseBought, uint256 quoteSpent)
    {
        return launchpad.buy(
            ILaunchpad.BuyData({
                account: msg.sender,
                token: launchToken,
                recipient: msg.sender,
                amountOutBase: amountOutBase,
                maxAmountInQuote: worstAmountInQuote
            })
        );
    }

    struct __RouteMetadata__ {
        address nextTokenIn;
        uint256 prevAmountOut;
        HopType prevHopType;
        HopType nextHopType;
    }

    /// @notice The route entry point
    /// @param tokenIn first token in route
    /// @param amountIn first amount in for a trade in the route
    /// @param amountOutMin slippage setting
    /// @param deadline timeout setting
    /// @param hops The hop specific data which is encoded using the "execute" functions of GTERouterAPI
    function executeRoute(
        address tokenIn,
        uint256 amountIn,
        uint256 amountOutMin,
        uint256 deadline,
        bytes[] calldata hops
    ) external nonReentrant inTime(deadline) returns (uint256 finalAmountOut, address finalTokenOut) {
        (finalAmountOut, finalTokenOut) = _executeAllHops(tokenIn, amountIn, hops);

        if (finalAmountOut < amountOutMin) revert SlippageToleranceExceeded();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     INTERNAL WRITES                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    function _assertValidCLOB(address clob) internal view {
        if (!clobAdminPanel.isMarket(address(clob))) revert InvalidCLOBAddress();
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  EXECUTE_ROUTE HELPERS                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    // slither-disable-start incorrect-equality
    function _executeAllHops(address tokenIn, uint256 amountIn, bytes[] calldata hops)
        internal
        returns (uint256 finalAmountOut, address finalTokenOut)
    {
        __RouteMetadata__ memory route = __RouteMetadata__({
            nextTokenIn: tokenIn,
            prevAmountOut: amountIn,
            prevHopType: HopType.NULL,
            nextHopType: hops[0].getHopType()
        });

        for (uint256 i = 0; i < hops.length; i++) {
            HopType currHopType = route.nextHopType;
            route.nextHopType = (i == hops.length - 1) ? HopType.NULL : hops[i + 1].getHopType();

            if (currHopType == HopType.CLOB_FILL) {
                (route.prevAmountOut, route.nextTokenIn) = _executeClobPostFillOrder(route, hops[i]);
            } else if (currHopType == HopType.UNI_V2_SWAP) {
                (route.prevAmountOut, route.nextTokenIn) = _executeUniV2SwapExactTokensForTokens(route, hops[i]);
            }

            route.prevHopType = currHopType;
        }

        return (route.prevAmountOut, route.nextTokenIn);
    }
    // slither-disable-end incorrect-equality

    // slither-disable-start calls-loop
    function _executeClobPostFillOrder(__RouteMetadata__ memory route, bytes calldata hop)
        internal
        returns (uint256 amountOut, address tokenOut)
    {
        tokenOut = abi.decode(hop[1:], (ClobHopArgs)).tokenOut;

        address market = clobAdminPanel.getMarketAddress(route.nextTokenIn, tokenOut);

        if (market == address(0)) revert CLOBDoesNotExist();

        // slither-disable-next-line uninitialized-local Construct post limit calldata
        ICLOB.PostFillOrderArgs memory fillArgs;

        fillArgs.side = ICLOB(market).getQuoteToken() == route.nextTokenIn ? Side.BUY : Side.SELL;
        fillArgs.priceLimit = fillArgs.side == Side.BUY ? type(uint256).max : 0; // executeRoute enforced slippage at the end
        fillArgs.amountIsBase = fillArgs.side == Side.SELL;

        fillArgs.amount = route.prevAmountOut;
        fillArgs.fillOrderType = ICLOB.FillOrderType.FILL_OR_KILL;

        // Execute trade
        ICLOB.PostFillOrderResult memory result = ICLOB(market).postFillOrder(msg.sender, fillArgs);

        // Actual amount out, net of fees
        amountOut = fillArgs.side == Side.BUY
            ? uint256(result.baseTokenAmountTraded) - result.takerFee
            : uint256(result.quoteTokenAmountTraded) - result.takerFee;

        return (amountOut, tokenOut);
    }

    function _executeUniV2SwapExactTokensForTokens(__RouteMetadata__ memory route, bytes calldata hop)
        internal
        returns (uint256 amountOut, address tokenOut)
    {
        UniV2HopArgs memory args = abi.decode(hop[1:], (UniV2HopArgs));
        address[] memory path = args.path;

        if (path[0] != route.nextTokenIn) revert InvalidTokenRoute();

        if (route.prevHopType != HopType.UNI_V2_SWAP) {
            acctManager.withdrawToRouter(msg.sender, route.nextTokenIn, route.prevAmountOut);
        }

        path[0].safeApprove(address(uniV2Router), route.prevAmountOut);

        uint256[] memory amounts = uniV2Router.swapExactTokensForTokens(
            route.prevAmountOut,
            0, // No amountOutMin since executeRoute enforces slippage
            path,
            address(this), // Always send to router
            block.timestamp
        );

        tokenOut = path[path.length - 1];
        amountOut = amounts[amounts.length - 1];

        if (route.nextHopType != HopType.UNI_V2_SWAP) _accountDepositInternal(tokenOut, amountOut);

        return (amounts[amounts.length - 1], tokenOut);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    TRANSFER COORDINATOR                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Deposits an amount of token sitting in the router to the caller's spot account
    function _accountDepositInternal(address token, uint256 amount) internal {
        token.safeApprove(address(acctManager), amount);
        acctManager.depositFromRouter(msg.sender, token, amount);
    }

    // slither-disable-end calls-loop
}

library HopLib {
    function getHopType(bytes calldata hop) internal pure returns (GTERouter.HopType) {
        return GTERouter.HopType(uint8(bytes1(hop[0:1])));
    }
}
