// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

// Local types, libs, and interfaces
import {ICLOB} from "./ICLOB.sol";
import {ICLOBManager} from "./ICLOBManager.sol";
import {IAccountManager} from "../account-manager/IAccountManager.sol";
import {CLOBStorageLib} from "./types/Book.sol";
import {TransientMakerData, MakerCredit} from "./types/TransientMakerData.sol";
import {Order, OrderLib, OrderId, OrderIdLib, Side} from "./types/Order.sol";
import {Book, BookLib, Limit, MarketConfig, MarketSettings} from "./types/Book.sol";

// Internal package types, libs, and interfaces
import {IOperator} from "contracts/utils/interfaces/IOperator.sol";
import {OperatorRoles} from "contracts/utils/Operator.sol";
import {OperatorHelperLib} from "contracts/utils/types/OperatorHelperLib.sol";
import {EventNonceLib as CLOBEventNonce} from "contracts/utils/types/EventNonce.sol";

// Solady and OZ imports
import {SafeCastLib} from "@solady/utils/SafeCastLib.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

/**
 * @title CLOB
 * Main spot market contract for trading asset pairs on an orderbook
 */
contract CLOB is ICLOB, Ownable2StepUpgradeable {
    using OrderLib for *;
    using OrderIdLib for uint256;
    using OrderIdLib for address;
    using FixedPointMathLib for uint256;
    using SafeCastLib for uint256;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           EVENTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev sig: 0xc0208cc462e0f7d7b2329363da41c40e123ba2c9db4b8b03a183140d67ad1c60
    event CancelFailed(uint256 indexed eventNonce, uint256 orderId, address owner);
    /// @dev sig: 0x000db81a45376092a12f01bd951541c58dadfbee19b3abc4697dc2cc5e9b23d1
    event MaxLimitOrdersPerTxUpdated(uint8 newMaxLimits, uint256 nonce);
    /// @dev sig: 0xdf07ebd269c613b8a3f2d3a9b3763bfed22597dc93ca6f40caf8773ebabf7d50
    event TickSizeUpdated(uint256 newTickSize, uint256 nonce);
    /// @dev sig: 0xc4a46c9948e01e547abd16e75dc8fe9188e51223adaa63628987231721f1a175
    event LimitOrderSubmitted(
        uint256 indexed eventNonce, address indexed owner, uint256 orderId, PostLimitOrderArgs args
    );

    /// @dev sig: 0xa29c2a8452ff5e5b8761380398807d8bdf90000d5d47150885ca12872c3a633a
    /// @dev negative if outgoing, positive if incoming. Includes fees
    event LimitOrderProcessed(
        uint256 indexed eventNonce,
        address indexed account,
        uint256 indexed orderId,
        uint256 amountPostedInBase,
        int256 quoteTokenAmountTraded,
        int256 baseTokenAmountTraded,
        uint256 takerFee
    );

    /// @dev sig: 0xfe554b360bf5fbcb8c25503e7d4856f541a95cdc06c7bd09db796a8b8a1c63c1
    event FillOrderSubmitted(
        uint256 indexed eventNonce, address indexed owner, uint256 orderId, PostFillOrderArgs args
    );

    /// @dev sig: 0x1788bdd4ba6258b91406af719d1791cfc448cfeaf6850c9e016d79e61201f897
    /// @dev negative if outgoing, positive if incoming. Includes fees
    event FillOrderProcessed(
        uint256 indexed eventNonce,
        address indexed account,
        uint256 indexed orderId,
        int256 quoteTokenAmountTraded,
        int256 baseTokenAmountTraded,
        uint256 takerFee
    );

    /// @dev sig: 0xa84066ca7c3818fb5a7daa425764c271a1e4cec2c622ac3aeb7e41ff68800a63
    event OrderCanceled(
        uint256 indexed eventNonce,
        uint256 indexed orderId,
        address indexed owner,
        uint256 quoteTokenRefunded,
        uint256 baseTokenRefunded,
        CancelType context
    );

    /// @dev sig: 0xa93c2d52ea42b9ef4e405dd5e4447e9a3f7e50261f11e571e43bc7452556860c
    event OrderAmended(
        uint256 indexed eventNonce, Order preAmend, AmendArgs args, int256 quoteTokenDelta, int256 baseTokenDelta
    );

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                           ERRORS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev sig: 0xb82df155
    error ZeroOrder();
    /// @dev sig: 0x91b373e1
    error AmendInvalid();
    /// @dev sig: 0xc56873ba
    error OrderExpired();
    /// @dev sig: 0xd8a00083
    error ZeroCostTrade();
    /// @dev sig: 0xf1a5cd31
    error FOKOrderNotFilled();
    /// @dev sig: 0xba2ea531
    error AmendUnauthorized();
    /// @dev sig: 0xf99412b1
    error CancelUnauthorized();
    /// @dev sig: 0xd268c85f
    error ManagerUnauthorized();
    /// @dev sig: 0xd093feb7
    error FactoryUnauthorized();
    /// @dev sig: 0x3e27eb6d
    error PostOnlyOrderWouldFill();
    /// @dev sig: 0xb134397c
    error AmendNonPostOnlyInvalid();
    /// @dev sig: 0x315ff5e5
    error MaxOrdersInBookPostNotCompetitive();

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                        CONSTANTS                           */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev The abi version of this impl so the indexer can handle event-changing upgrades
    uint256 public constant ABI_VERSION = 1;

    /// @dev The global router address available to all CLOBs that can bypass the operator check
    address public immutable gteRouter;
    /// @dev The operator contract for role-based access control (same as accountManager)
    IOperator public immutable operator;
    /// @dev The factory that created this contract and controls its settings as well as processing maker settlement
    ICLOBManager public immutable factory;
    /// @dev The account manager contract for direct balance operations (and operator checks)
    IAccountManager public immutable accountManager;
    /// @dev Maximum number of unique price levels (limits) allowed per side of the order book
    /// before the least competitive orders get bumped
    uint256 public immutable maxNumLimitsPerSide;

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                         MODIFIERS                          */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    modifier onlySenderOrOperator(address account, OperatorRoles requiredRole) {
        OperatorHelperLib.onlySenderOrOperator(operator, gteRouter, account, requiredRole);
        _;
    }

    modifier onlyManager() {
        if (msg.sender != address(factory)) revert ManagerUnauthorized();
        _;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*               CONSTRUCTOR AND INITIALIZATION               */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor(address _factory, address _gteRouter, address _accountManager, uint256 _maxNumLimitsPerSide) {
        factory = ICLOBManager(_factory);
        gteRouter = _gteRouter;
        operator = IOperator(_accountManager);
        accountManager = IAccountManager(_accountManager);
        maxNumLimitsPerSide = _maxNumLimitsPerSide;
        _disableInitializers();
    }

    /// @notice Initializes the `marketConfig`, `marketSettings`, and `initialOwner` of the market
    function initialize(MarketConfig memory marketConfig, MarketSettings memory marketSettings, address initialOwner)
        external
        initializer
    {
        __CLOB_init(marketConfig, marketSettings, initialOwner);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    EXTERNAL GETTERS                        */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Gets base token
    function getBaseToken() external view returns (address) {
        return _getStorage().config().baseToken;
    }

    /// @notice Gets quote token
    function getQuoteToken() external view returns (address) {
        return _getStorage().config().quoteToken;
    }

    /// @notice Gets the base token amount equivalent to `quoteAmount` at a given `price`
    /// @dev This price does not have to be within tick size
    function getBaseTokenAmount(uint256 price, uint256 quoteAmount) external view returns (uint256) {
        return _getStorage().getBaseTokenAmount(price, quoteAmount);
    }

    /// @notice Gets the quote token amount equivalent to `baseAmount` at a given `price`
    /// @dev This price dos not have to be within tick size
    function getQuoteTokenAmount(uint256 price, uint256 baseAmount) external view returns (uint256) {
        return _getStorage().getQuoteTokenAmount(price, baseAmount);
    }

    /// @notice Gets the market config
    function getMarketConfig() external view returns (MarketConfig memory) {
        return _getStorage().config();
    }

    /// @notice Gets the market settings
    function getMarketSettings() external view returns (MarketSettings memory) {
        return _getStorage().settings();
    }

    /// @notice Gets tick size
    function getTickSize() external view returns (uint256) {
        return _getStorage().settings().tickSize;
    }

    /// @notice Gets lot size in base
    function getLotSizeInBase() external view returns (uint256) {
        return _getStorage().settings().lotSizeInBase;
    }

    /// @notice Gets quote and base open interest
    function getOpenInterest() external view returns (uint256 quoteOi, uint256 baseOi) {
        return (_getStorage().metadata().quoteTokenOpenInterest, _getStorage().metadata().baseTokenOpenInterest);
    }

    /// @notice Gets an order in the book from its id
    function getOrder(uint256 orderId) external view returns (Order memory) {
        return _getStorage().orders[orderId.toOrderId()];
    }

    /// @notice Gets top of book as price (max bid and min ask)
    function getTOB() external view returns (uint256 maxBid, uint256 minAsk) {
        return (_getStorage().getBestBidPrice(), _getStorage().getBestAskPrice());
    }

    /// @notice Gets the bid or ask Limit at a price depending on `side`
    function getLimit(uint256 price, Side side) external view returns (Limit memory) {
        return _getStorage().getLimit(price, side);
    }

    /// @notice Gets total bid limit orders in the book
    function getNumBids() external view returns (uint256) {
        return _getStorage().metadata().numBids;
    }

    /// @notice Gets total ask limit orders in the book
    function getNumAsks() external view returns (uint256) {
        return _getStorage().metadata().numAsks;
    }

    /// @notice Gets a list of orders, starting at an orderId
    function getNextOrders(uint256 startOrderId, uint256 numOrders) external view returns (Order[] memory) {
        return _getStorage().getNextOrders(startOrderId.toOrderId(), numOrders);
    }

    /// @notice Gets the next populated higher price limit to `price` on a side of the book
    function getNextBiggestPrice(uint256 price, Side side) external view returns (uint256) {
        return _getStorage().getNextBiggestPrice(price, side);
    }

    /// @notice Gets the next populated lower price limit to `price` on a side of the book
    function getNextSmallestPrice(uint256 price, Side side) external view returns (uint256) {
        return _getStorage().getNextSmallestPrice(price, side);
    }

    /// @notice Gets the next order id (nonce) that will be used upon placing an order
    /// @dev Placing both limit and fill orders increment the next orderId
    function getNextOrderId() external view returns (uint256) {
        return OrderIdLib.getOrderId(address(0), _getStorage().metadata().orderIdCounter + 1);
    }

    /// @notice Gets the current event nonce
    function getEventNonce() external view returns (uint256) {
        return CLOBEventNonce.getCurrentNonce();
    }

    /// @notice Gets `pageSize` of orders from TOB down from a `startPrice` and on a given `side` of the book
    function getOrdersPaginated(uint256 startPrice, Side side, uint256 pageSize)
        external
        view
        returns (Order[] memory result, Order memory nextOrder)
    {
        Book storage ds = _getStorage();

        nextOrder = side == Side.BUY
            ? ds.orders[ds.bidLimits[startPrice].headOrder]
            : ds.orders[ds.askLimits[startPrice].headOrder];

        return ds.getOrdersPaginated(nextOrder, pageSize);
    }

    /// @notice Gets `pageSize` of orders from TOB down, starting at `startOrderId`
    function getOrdersPaginated(OrderId startOrderId, uint256 pageSize)
        external
        view
        returns (Order[] memory result, Order memory nextOrder)
    {
        Book storage ds = _getStorage();
        nextOrder = ds.orders[startOrderId];

        return ds.getOrdersPaginated(nextOrder, pageSize);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                     AUTH-ONLY SETTERS                      */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Sets the new max limits per txn
    function setMaxLimitsPerTx(uint8 newMaxLimits) external onlyManager {
        _getStorage().setMaxLimitsPerTx(newMaxLimits);
    }

    /// @notice Sets the tick size of the book
    /// @dev New orders' limit prices % tickSize must be 0
    function setTickSize(uint256 tickSize) external onlyManager {
        _getStorage().setTickSize(tickSize);
    }

    /// @notice Sets the minimum amount an order (in base) must be to be placed on the book
    /// @dev Reducing an order below this amount will cause the order to get cancelled
    function setMinLimitOrderAmountInBase(uint256 newMinLimitOrderAmountInBase) external onlyManager {
        _getStorage().setMinLimitOrderAmountInBase(newMinLimitOrderAmountInBase);
    }

    /// @notice Sets the lot size in base for standardized trade sizes
    /// @dev Orders must be multiples of lot size. Setting to 0 disables lot size restrictions
    function setLotSizeInBase(uint256 newLotSizeInBase) external onlyManager {
        _getStorage().setLotSizeInBase(newLotSizeInBase);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                 EXTERNAL ORDER PLACEMENT                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @notice Posts a fill (taker) order for an `account`
    /// @dev Fill orders don't enforce lot size restrictions as they consume existing liquidity
    function postFillOrder(address account, PostFillOrderArgs calldata args)
        external
        onlySenderOrOperator(account, OperatorRoles.CLOB_FILL)
        returns (PostFillOrderResult memory)
    {
        Book storage ds = _getStorage();

        uint256 orderId = ds.incrementOrderId();
        Order memory newOrder = args.toOrder(orderId, account);

        emit FillOrderSubmitted(CLOBEventNonce.inc(), account, orderId, args);

        if (args.side == Side.BUY) return _processFillBidOrder(ds, account, newOrder, args);
        else return _processFillAskOrder(ds, account, newOrder, args);
    }

    /// @notice Posts a limit order for `account`
    function postLimitOrder(address account, PostLimitOrderArgs calldata args)
        external
        onlySenderOrOperator(account, OperatorRoles.CLOB_LIMIT)
        returns (PostLimitOrderResult memory)
    {
        Book storage ds = _getStorage();

        ds.assertLimitPriceInBounds(args.price);
        ds.assertLimitOrderAmountInBounds(args.amountInBase);
        ds.assertLotSizeCompliant(args.amountInBase);

        // Max limits per tx is enforced on the caller to allow for whitelisted operators
        // to implement their own max limit logic.
        ds.incrementLimitsPlaced(address(factory), msg.sender);

        uint256 orderId;
        if (args.clientOrderId == 0) {
            orderId = ds.incrementOrderId();
        } else {
            orderId = account.getOrderId(args.clientOrderId);
            ds.assertUnusedOrderId(orderId);
        }

        Order memory newOrder = args.toOrder(orderId, account);

        if (newOrder.isExpired()) revert OrderExpired();

        emit LimitOrderSubmitted(CLOBEventNonce.inc(), account, orderId, args);

        if (args.side == Side.BUY) return _processLimitBidOrder(ds, account, newOrder, args);
        else return _processLimitAskOrder(ds, account, newOrder, args);
    }

    /// @notice Amends an existing order for `account`
    function amend(address account, AmendArgs calldata args)
        external
        onlySenderOrOperator(account, OperatorRoles.CLOB_LIMIT)
        returns (int256 quoteDelta, int256 baseDelta)
    {
        Book storage ds = _getStorage();
        Order storage order = ds.orders[args.orderId.toOrderId()];

        if (order.id.unwrap() == 0) revert OrderLib.OrderNotFound();
        if (order.owner != account) revert AmendUnauthorized();
        if (args.limitOrderType != LimitOrderType.POST_ONLY) revert AmendNonPostOnlyInvalid();

        ds.assertLimitPriceInBounds(args.price);
        ds.assertLotSizeCompliant(args.amountInBase);

        // Update order
        (quoteDelta, baseDelta) = _processAmend(ds, order, args);
    }

    /// @notice Cancels a list of orders for `account`
    function cancel(address account, CancelArgs memory args)
        external
        onlySenderOrOperator(account, OperatorRoles.CLOB_LIMIT)
        returns (uint256, uint256)
    {
        Book storage ds = _getStorage();
        (address quoteToken, address baseToken) = (ds.config().quoteToken, ds.config().baseToken);

        (uint256 totalQuoteTokenRefunded, uint256 totalBaseTokenRefunded) = _executeCancel(ds, account, args);

        if (totalBaseTokenRefunded > 0) accountManager.creditAccount(account, baseToken, totalBaseTokenRefunded);
        if (totalQuoteTokenRefunded > 0) accountManager.creditAccount(account, quoteToken, totalQuoteTokenRefunded);

        return (totalQuoteTokenRefunded, totalBaseTokenRefunded);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    INTERNAL FILL LOGIC                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Performs matching and settlement for a bid fill order
    function _processFillBidOrder(
        Book storage ds,
        address account,
        Order memory newOrder,
        PostFillOrderArgs memory args
    ) private returns (PostFillOrderResult memory) {
        (uint256 totalQuoteSent, uint256 totalBaseReceived) = _matchIncomingBid(ds, newOrder, args.amountIsBase);

        if (totalQuoteSent == 0 || totalBaseReceived == 0) revert ZeroCostTrade();
        if (args.fillOrderType == FillOrderType.FILL_OR_KILL && newOrder.amount > 0) revert FOKOrderNotFilled();

        // slither-disable-next-line reentrancy-events This external call is to the factory
        uint256 takerFee = _settleIncomingOrder(ds, account, Side.BUY, totalQuoteSent, totalBaseReceived);

        emit FillOrderProcessed(
            CLOBEventNonce.inc(),
            account,
            newOrder.id.unwrap(),
            -totalQuoteSent.toInt256(),
            totalBaseReceived.toInt256(),
            takerFee
        );

        return PostFillOrderResult(
            account, newOrder.id.unwrap(), -totalQuoteSent.toInt256(), totalBaseReceived.toInt256(), takerFee
        );
    }

    /// @dev Performs matching and settlement for an ask fill order
    function _processFillAskOrder(
        Book storage ds,
        address account,
        Order memory newOrder,
        PostFillOrderArgs memory args
    ) private returns (PostFillOrderResult memory) {
        (uint256 quoteReceived, uint256 baseSent) = _matchIncomingAsk(ds, newOrder, args.amountIsBase);

        if (quoteReceived == 0 || baseSent == 0) revert ZeroCostTrade();
        if (args.fillOrderType == FillOrderType.FILL_OR_KILL && newOrder.amount > 0) revert FOKOrderNotFilled();

        // slither-disable-next-line reentrancy-events This external call is to the factory
        uint256 takerFee = _settleIncomingOrder(ds, account, Side.SELL, quoteReceived, baseSent);

        emit FillOrderProcessed(
            CLOBEventNonce.inc(),
            account,
            newOrder.id.unwrap(),
            quoteReceived.toInt256(),
            -baseSent.toInt256(),
            takerFee
        );

        return
            PostFillOrderResult(account, newOrder.id.unwrap(), quoteReceived.toInt256(), -baseSent.toInt256(), takerFee);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   INTERNAL LIMIT LOGIC                     */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Places a bid limit order onto the book, matching and settling any fill if possible
    function _processLimitBidOrder(
        Book storage ds,
        address account,
        Order memory newOrder,
        PostLimitOrderArgs memory args
    ) internal returns (PostLimitOrderResult memory) {
        (uint256 postAmount, uint256 quoteTokenAmountSent, uint256 baseTokenAmountReceived) =
            _executeBidLimitOrder(ds, newOrder, args.limitOrderType);

        if (postAmount + quoteTokenAmountSent + baseTokenAmountReceived == 0) revert ZeroOrder();

        if (baseTokenAmountReceived != quoteTokenAmountSent && baseTokenAmountReceived & quoteTokenAmountSent == 0) {
            revert ZeroCostTrade();
        }

        uint256 eventNonce = CLOBEventNonce.inc(); // keep stack from blowing

        uint256 takerFee =
            _settleIncomingOrder(ds, account, Side.BUY, quoteTokenAmountSent + postAmount, baseTokenAmountReceived);

        emit LimitOrderProcessed(
            eventNonce,
            account,
            newOrder.id.unwrap(),
            newOrder.amount,
            -quoteTokenAmountSent.toInt256(),
            baseTokenAmountReceived.toInt256(),
            takerFee
        );

        return PostLimitOrderResult(
            account,
            newOrder.id.unwrap(),
            newOrder.amount,
            -quoteTokenAmountSent.toInt256(),
            baseTokenAmountReceived.toInt256(),
            takerFee
        );
    }

    /// @dev Places an ask limit order onto the book, matching and settling any fill if possible
    function _processLimitAskOrder(
        Book storage ds,
        address account,
        Order memory newOrder,
        PostLimitOrderArgs memory args
    ) internal returns (PostLimitOrderResult memory) {
        (uint256 postAmount, uint256 quoteTokenAmountReceived, uint256 baseTokenAmountSent) =
            _executeAskLimitOrder(ds, newOrder, args.limitOrderType);

        if (postAmount + quoteTokenAmountReceived + baseTokenAmountSent == 0) revert ZeroOrder();

        if (baseTokenAmountSent != quoteTokenAmountReceived && baseTokenAmountSent & quoteTokenAmountReceived == 0) {
            revert ZeroCostTrade();
        }

        uint256 eventNonce = CLOBEventNonce.inc(); // Keep stack from blowing

        uint256 takerFee =
            _settleIncomingOrder(ds, account, Side.SELL, quoteTokenAmountReceived, baseTokenAmountSent + postAmount);

        emit LimitOrderProcessed(
            eventNonce,
            account,
            newOrder.id.unwrap(),
            newOrder.amount,
            quoteTokenAmountReceived.toInt256(),
            -baseTokenAmountSent.toInt256(),
            takerFee
        );

        return PostLimitOrderResult(
            account,
            newOrder.id.unwrap(),
            newOrder.amount,
            quoteTokenAmountReceived.toInt256(),
            -baseTokenAmountSent.toInt256(),
            takerFee
        );
    }

    /// @dev Performs the core matching and placement of a bid limit order into the book
    function _executeBidLimitOrder(Book storage ds, Order memory newOrder, LimitOrderType limitOrderType)
        internal
        returns (uint256 postAmount, uint256 quoteTokenAmountSent, uint256 baseTokenAmountReceived)
    {
        if (limitOrderType == LimitOrderType.POST_ONLY && ds.getBestAskPrice() <= newOrder.price) {
            revert PostOnlyOrderWouldFill();
        }

        // Attempt to fill any of the incoming limit order that's overlapping into asks
        (uint256 totalQuoteSent, uint256 totalBaseReceived) = _matchIncomingBid(ds, newOrder, true);

        // NOOP, there is no more size left after filling to create a limit order
        if (newOrder.amount < ds.settings().minLimitOrderAmountInBase) {
            newOrder.amount = 0;
            return (postAmount, totalQuoteSent, totalBaseReceived);
        }

        // The book is full, pop the least competitive order (or revert if incoming is the least competitive)
        if (ds.bidTree.size() == maxNumLimitsPerSide) {
            uint256 minBidPrice = ds.getWorstBidPrice();
            if (newOrder.price <= minBidPrice) revert MaxOrdersInBookPostNotCompetitive();

            _removeNonCompetitiveOrder(ds, ds.orders[ds.bidLimits[minBidPrice].tailOrder]);
        }

        // After filling, the order still has sufficient size and can be placed as a limit
        ds.addOrderToBook(newOrder);
        postAmount = ds.getQuoteTokenAmount(newOrder.price, newOrder.amount);

        return (postAmount, totalQuoteSent, totalBaseReceived);
    }

    /// @dev Performs the core matching and placement of an ask limit order into the book
    function _executeAskLimitOrder(Book storage ds, Order memory newOrder, LimitOrderType limitOrderType)
        internal
        returns (uint256 postAmount, uint256 quoteTokenAmountReceived, uint256 baseTokenAmountSent)
    {
        if (limitOrderType == LimitOrderType.POST_ONLY && ds.getBestBidPrice() >= newOrder.price) {
            revert PostOnlyOrderWouldFill();
        }

        // Attempt to fill any of the incoming limit order that's overlapping into bids
        (quoteTokenAmountReceived, baseTokenAmountSent) = _matchIncomingAsk(ds, newOrder, true);

        // NOOP, there is no more size left after filling to create a limit order
        if (newOrder.amount < ds.settings().minLimitOrderAmountInBase) {
            newOrder.amount = 0;
            return (postAmount, quoteTokenAmountReceived, baseTokenAmountSent);
        }

        // The book is full, pop the least competitive order (or revert if incoming is the least competitive)
        if (ds.askTree.size() == maxNumLimitsPerSide) {
            uint256 maxAskPrice = ds.getWorstAskPrice();
            if (newOrder.price >= maxAskPrice) revert MaxOrdersInBookPostNotCompetitive();

            _removeNonCompetitiveOrder(ds, ds.orders[ds.askLimits[maxAskPrice].tailOrder]);
        }

        // After filling, the order still has sufficient size and can be placed as a limit
        ds.addOrderToBook(newOrder);
        postAmount = newOrder.amount;

        return (postAmount, quoteTokenAmountReceived, baseTokenAmountSent);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    INTERNAL AMEND LOGIC                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Performs the amending of an order
    function _processAmend(Book storage ds, Order storage order, AmendArgs calldata args)
        internal
        returns (int256 quoteTokenDelta, int256 baseTokenDelta)
    {
        Order memory preAmend = order;
        address maker = preAmend.owner;

        if (args.cancelTimestamp.isExpired() || args.amountInBase < ds.settings().minLimitOrderAmountInBase) {
            revert AmendInvalid();
        }

        // Check lot size compliance after other validations
        ds.assertLotSizeCompliant(args.amountInBase);

        if (order.side != args.side || order.price != args.price) {
            // change place in book
            (quoteTokenDelta, baseTokenDelta) = _executeAmendNewOrder(ds, order, args);
        } else {
            // change amount
            (quoteTokenDelta, baseTokenDelta) = _executeAmendAmount(ds, order, args.amountInBase);

            if (quoteTokenDelta + baseTokenDelta == 0) revert ZeroOrder();
        }

        emit OrderAmended(CLOBEventNonce.inc(), preAmend, args, quoteTokenDelta, baseTokenDelta);

        _settleAmend(ds, maker, quoteTokenDelta, baseTokenDelta);
    }

    /// @dev Performs the removal and replacement of an amended order with a new price or side
    function _executeAmendNewOrder(Book storage ds, Order storage order, AmendArgs calldata args)
        internal
        returns (int256 quoteTokenDelta, int256 baseTokenDelta)
    {
        Order memory newOrder;

        newOrder.owner = order.owner;
        newOrder.id = order.id;
        newOrder.side = args.side;
        newOrder.price = args.price;
        newOrder.amount = args.amountInBase;
        newOrder.cancelTimestamp = uint32(args.cancelTimestamp);

        if (order.side == Side.BUY) quoteTokenDelta = ds.getQuoteTokenAmount(order.price, order.amount).toInt256();
        else baseTokenDelta = order.amount.toInt256();

        ds.removeOrderFromBook(order);

        uint256 postAmount;
        if (args.side == Side.BUY) {
            (postAmount,,) = _executeBidLimitOrder(ds, newOrder, args.limitOrderType);

            quoteTokenDelta -= postAmount.toInt256();
        } else {
            (postAmount,,) = _executeAskLimitOrder(ds, newOrder, args.limitOrderType);

            baseTokenDelta -= postAmount.toInt256();
        }
    }

    /// @dev Performs the updating of an amended order with a new amount
    function _executeAmendAmount(Book storage ds, Order storage order, uint256 amount)
        internal
        returns (int256 quoteTokenDelta, int256 baseTokenDelta)
    {
        if (order.side == Side.BUY) {
            int256 oldAmountInQuote = ds.getQuoteTokenAmount(order.price, order.amount).toInt256();
            int256 newAmountInQuote = ds.getQuoteTokenAmount(order.price, amount).toInt256();

            quoteTokenDelta = oldAmountInQuote - newAmountInQuote;

            ds.metadata().quoteTokenOpenInterest =
                uint256(ds.metadata().quoteTokenOpenInterest.toInt256() - quoteTokenDelta);
        } else {
            baseTokenDelta = order.amount.toInt256() - amount.toInt256();

            ds.metadata().baseTokenOpenInterest =
                uint256(ds.metadata().baseTokenOpenInterest.toInt256() - baseTokenDelta);
        }

        order.amount = amount;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  INTERNAL MATCHING LOGIC                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Internal struct to prevent blowing stack
    struct __MatchData__ {
        uint256 matchedAmount;
        uint256 baseDelta;
        uint256 quoteDelta;
    }

    /// @dev Match incoming bid order to best asks
    function _matchIncomingBid(Book storage ds, Order memory incomingOrder, bool amountIsBase)
        internal
        returns (uint256 totalQuoteSent, uint256 totalBaseReceived)
    {
        uint256 bestAskPrice = ds.getBestAskPrice();

        while (bestAskPrice <= incomingOrder.price && incomingOrder.amount > 0) {
            Limit storage limit = ds.askLimits[bestAskPrice];
            Order storage bestAskOrder = ds.orders[limit.headOrder];

            if (bestAskOrder.isExpired()) {
                _removeExpiredAsk(ds, bestAskOrder);
                bestAskPrice = ds.getBestAskPrice();
                continue;
            }

            // slither-disable-next-line uninitialized-local
            __MatchData__ memory currMatch =
                _matchIncomingOrder(ds, bestAskOrder, incomingOrder, bestAskPrice, amountIsBase);

            // Break if no tradeable amount can be filled due to lot size constraints.
            // This prevents infinite loops when dust amounts cannot fill a single lot.
            if (currMatch.baseDelta == 0) break;

            incomingOrder.amount -= currMatch.matchedAmount;

            totalQuoteSent += currMatch.quoteDelta;
            totalBaseReceived += currMatch.baseDelta;

            bestAskPrice = ds.getBestAskPrice();
        }
    }

    /// @dev Match incoming ask order to best bids
    function _matchIncomingAsk(Book storage ds, Order memory incomingOrder, bool amountIsBase)
        internal
        returns (uint256 totalQuoteTokenReceived, uint256 totalBaseTokenSent)
    {
        uint256 bestBidPrice = ds.getBestBidPrice();

        while (bestBidPrice >= incomingOrder.price && incomingOrder.amount > 0) {
            Limit storage limit = ds.bidLimits[bestBidPrice];
            Order storage bestBidOrder = ds.orders[limit.headOrder];

            if (bestBidOrder.isExpired()) {
                _removeExpiredBid(ds, bestBidOrder);
                bestBidPrice = ds.getBestBidPrice();
                continue;
            }

            // slither-disable-next-line uninitialized-local
            __MatchData__ memory currMatch =
                _matchIncomingOrder(ds, bestBidOrder, incomingOrder, bestBidPrice, amountIsBase);

            // Break if no tradeable amount can be filled due to lot size constraints.
            // This prevents infinite loops when dust amounts cannot fill a single lot.
            if (currMatch.baseDelta == 0) break;

            incomingOrder.amount -= currMatch.matchedAmount;

            totalQuoteTokenReceived += currMatch.quoteDelta;
            totalBaseTokenSent += currMatch.baseDelta;

            bestBidPrice = ds.getBestBidPrice();
        }
    }

    /// @dev Matches an incoming order to its next counterparty order, crediting the maker and removing the counterparty order if fully filled
    function _matchIncomingOrder(
        Book storage ds,
        Order storage makerOrder,
        Order memory takerOrder,
        uint256 matchedPrice,
        bool amountIsBase
    ) internal returns (__MatchData__ memory matchData) {
        uint256 matchedBase = makerOrder.amount;
        uint256 lotSize = ds.settings().lotSizeInBase;

        if (amountIsBase) {
            // denominated in base
            matchData.baseDelta = (matchedBase.min(takerOrder.amount) / lotSize) * lotSize;
            matchData.quoteDelta = ds.getQuoteTokenAmount(matchedPrice, matchData.baseDelta);
            matchData.matchedAmount = matchData.baseDelta;
        } else {
            // denominated in quote
            matchData.baseDelta =
                (matchedBase.min(ds.getBaseTokenAmount(matchedPrice, takerOrder.amount)) / lotSize) * lotSize;
            matchData.quoteDelta = ds.getQuoteTokenAmount(matchedPrice, matchData.baseDelta);
            matchData.matchedAmount = matchData.baseDelta != matchedBase ? takerOrder.amount : matchData.quoteDelta;
        }

        // Early return if no tradeable amount due to lot size constraints (dust)
        if (matchData.baseDelta == 0) return matchData;

        bool orderRemoved = matchData.baseDelta == matchedBase;

        // Handle token accounting for maker.
        if (takerOrder.side == Side.BUY) {
            TransientMakerData.addQuoteToken(makerOrder.owner, matchData.quoteDelta);

            if (!orderRemoved) ds.metadata().baseTokenOpenInterest -= matchData.baseDelta;
        } else {
            TransientMakerData.addBaseToken(makerOrder.owner, matchData.baseDelta);

            if (!orderRemoved) ds.metadata().quoteTokenOpenInterest -= matchData.quoteDelta;
        }

        if (orderRemoved) ds.removeOrderFromBook(makerOrder);
        else makerOrder.amount -= matchData.baseDelta;
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                    INTERNAL EXPIRY LOGIC                   */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Removes an expired ask, adding the order's amount to settlement data as a base refund
    function _removeExpiredAsk(Book storage ds, Order storage order) internal {
        uint256 baseTokenAmount = order.amount;

        // We can add the refund to maker fills because both cancelled asks and filled bids are credited in baseTokens
        TransientMakerData.addBaseToken(order.owner, baseTokenAmount);

        ds.removeOrderFromBook(order);
    }

    /// @dev Removes an expired bid, adding the order's amount to settlement as a quote refund
    function _removeExpiredBid(Book storage ds, Order storage order) internal {
        uint256 quoteTokenAmount = ds.getQuoteTokenAmount(order.price, order.amount);

        // We can add the refund to maker fills because both cancelled bids and filled asks are credited in quoteTokens
        TransientMakerData.addQuoteToken(order.owner, quoteTokenAmount);

        ds.removeOrderFromBook(order);
    }

    /// @notice Removes the least competitive order from the book
    function _removeNonCompetitiveOrder(Book storage ds, Order storage order) internal {
        uint256 quoteRefunded;
        uint256 baseRefunded;
        if (order.side == Side.BUY) {
            quoteRefunded = ds.getQuoteTokenAmount(order.price, order.amount);
            accountManager.creditAccountNoEvent(order.owner, address(ds.config().quoteToken), quoteRefunded);
        } else {
            baseRefunded = order.amount;
            accountManager.creditAccountNoEvent(order.owner, address(ds.config().baseToken), baseRefunded);
        }

        emit OrderCanceled(
            CLOBEventNonce.inc(),
            order.id.unwrap(),
            order.owner,
            quoteRefunded,
            baseRefunded,
            CancelType.NON_COMPETITIVE
        );

        ds.removeOrderFromBook(order);
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                   INTERNAL CANCEL LOGIC                    */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Performs the cancellation of an account's orders
    function _executeCancel(Book storage ds, address account, CancelArgs memory args)
        internal
        returns (uint256 totalQuoteTokenRefunded, uint256 totalBaseTokenRefunded)
    {
        uint256 numOrders = args.orderIds.length;
        for (uint256 i = 0; i < numOrders; i++) {
            uint256 orderId = args.orderIds[i];
            Order storage order = ds.orders[orderId.toOrderId()];

            if (order.isNull()) {
                emit CancelFailed(CLOBEventNonce.inc(), orderId, account);
                continue; // Order may have been matched
            } else if (order.owner != account) {
                revert CancelUnauthorized();
            }

            uint256 quoteTokenRefunded = 0;
            uint256 baseTokenRefunded = 0;

            if (order.side == Side.BUY) {
                quoteTokenRefunded = ds.getQuoteTokenAmount(order.price, order.amount);
                totalQuoteTokenRefunded += quoteTokenRefunded;
            } else {
                baseTokenRefunded = order.amount;
                totalBaseTokenRefunded += baseTokenRefunded;
            }

            ds.removeOrderFromBook(order);

            uint256 eventNonce = CLOBEventNonce.inc();
            emit OrderCanceled(eventNonce, orderId, account, quoteTokenRefunded, baseTokenRefunded, CancelType.USER);
        }
    }

    /*´:°•.°+.*•´.*:˚.°*.˚•´.°:°•.°•.*•´.*:˚.°*.˚•´.°:°•.°+.*•´.*:*/
    /*                  INTERNAL SETTLEMENT LOGIC                 */
    /*.•°:°.´+˚.*°.˚:*.´•*.+°.•°:´*.´•*.•°.•°:°.´:•˚°.*°.˚:*.´+°.•*/

    /// @dev Settles token accounting in the factory for the incoming trade
    function _settleIncomingOrder(
        Book storage ds,
        address account,
        Side side,
        uint256 quoteTokenAmount,
        uint256 baseTokenAmount
    ) internal returns (uint256 takerFee) {
        SettleParams memory settleParams;

        (settleParams.quoteToken, settleParams.baseToken) = (ds.config().quoteToken, ds.config().baseToken);

        settleParams.taker = account;
        settleParams.side = side;

        settleParams.takerQuoteAmount = quoteTokenAmount;
        settleParams.takerBaseAmount = baseTokenAmount;

        settleParams.makerCredits = TransientMakerData.getMakerCreditsAndClearStorage();

        return accountManager.settleIncomingOrder(settleParams);
    }

    /// @dev Settles the token deltas in the factory from an amend
    function _settleAmend(Book storage ds, address maker, int256 quoteTokenDelta, int256 baseTokenDelta) internal {
        if (quoteTokenDelta > 0) {
            accountManager.creditAccount(maker, address(ds.config().quoteToken), uint256(quoteTokenDelta));
        } else if (quoteTokenDelta < 0) {
            accountManager.debitAccount(maker, address(ds.config().quoteToken), uint256(-quoteTokenDelta));
        }

        if (baseTokenDelta > 0) {
            accountManager.creditAccount(maker, address(ds.config().baseToken), uint256(baseTokenDelta));
        } else if (baseTokenDelta < 0) {
            accountManager.debitAccount(maker, address(ds.config().baseToken), uint256(-baseTokenDelta));
        }
    }

    // This naming reflects OZ initializer naming
    // slither-disable-next-line naming-convention
    function __CLOB_init(MarketConfig memory marketConfig, MarketSettings memory marketSettings, address initialOwner)
        internal
    {
        __Ownable_init(initialOwner);
        CLOBStorageLib.init(_getStorage(), marketConfig, marketSettings);
    }

    /// @dev Helper to assign the storage slot to the Book struct
    function _getStorage() internal pure returns (Book storage) {
        return CLOBStorageLib._getCLOBStorage();
    }
}
