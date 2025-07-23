// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";
import "forge-std/Test.sol";
import {LibString} from "@solady/utils/LibString.sol";

import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {UpgradeableBeacon} from "@openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import {ERC1967Factory} from "@solady/utils/ERC1967Factory.sol";
// import {PerpManager} from "contracts/perps/PerpManager.sol"; // Removed
// import {//SimpleLaunchpad, ILaunchpad} from "contracts/launchpad///SimpleLaunchpad.sol"; // Removed
import {GTERouter} from "contracts/router/GTERouter.sol";
import {CLOBManager} from "contracts/clob/CLOBManager.sol";
import {ICLOBManager, SettingsParams} from "contracts/clob/ICLOBManager.sol";
import {ICLOB, Side} from "contracts/clob/ICLOB.sol";
import "contracts/clob/types/FeeData.sol";
import {Operator, OperatorRoles} from "contracts/utils/Operator.sol";

import {MarketMetadata} from "contracts/clob/types/Book.sol";
import {
    CLOB,
    MarketConfig,
    MarketSettings,
    Limit,
    Order,
    OrderId,
    OrderIdLib
} from "contracts/clob/CLOB.sol";

abstract contract ScriptProtector is Script, Test {
    using LibString for string;
    using stdStorage for StdStorage;
    using SafeTransferLib for address;
    using ScriptProtectorLib for bytes32;
    using StorageReaderLib for bytes32;
    using OrderIdLib for OrderId;

    // cast hash-message "i know what im doing"
    bytes32 public constant key = 0x3b33cf1fc7c4e49a355ed5f1cd7a5e22fe25e0aa3201a4e371b6a99c1bd29af0;

    ERC1967Factory public factory;
    address public deployer;
    uint256 public deployerPrivateKey;
    address public uniV2Router;
    address public weth;
    address public permit2;

    // Testnet proxy contracts
    address public operatorProxy;
    address public gteRouterProxy;
    address public clobManagerProxy;
    address public simpleLaunchpadProxy;
    address public bondingCurve;
    UpgradeableBeacon public beacon;

    uint256 internal constant U8 = StorageReaderLib.U8;
    uint256 internal constant BOOL = StorageReaderLib.BOOL;
    uint256 internal constant U32 = StorageReaderLib.U32;

    modifier DoNotRemove_EnsureValidScript() {
        bytes32 envKey = vm.envOr("SCRIPT_CALLER_KEY", bytes32(0));

        require(key == envKey, "\u26A0 Please call scripts using makefile to allow for abi-safety checks! \u26A0");
        _;
    }

    function run() external virtual DoNotRemove_EnsureValidScript {
        console.log("TEST: pre-script checks have passed");

        vm.createSelectFork("http://127.0.0.1:8545");

        vm.startBroadcast(0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80);

        MockERC20 tt = new MockERC20();
        tt.initialize("tt", "tt", 18);
    }

    modifier SetupScript() {
        deployer = vm.envAddress("DEPLOYER");
        deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        factory = ERC1967Factory(vm.envAddress("GTE_FACTORY_TESTNET"));
        uniV2Router = vm.envAddress("UNIV2_VANILLA_ROUTER_TESTNET");
        permit2 = vm.envAddress("PERMIT2_TESTNET");
        weth = vm.envAddress("WETH_TESTNET");

        beacon = UpgradeableBeacon(vm.envAddress("CLOB_BEACON_TESTNET"));
        operatorProxy =vm.envAddress("GTE_OPERATOR_TESTNET");
        gteRouterProxy = vm.envAddress("GTE_ROUTER_TESTNET");
        clobManagerProxy = vm.envAddress("CLOB_MANAGER_TESTNET");
        simpleLaunchpadProxy = vm.envAddress("GTE_LAUNCHPAD_TESTNET");
        beacon = UpgradeableBeacon(vm.envAddress("CLOB_BEACON_TESTNET"));
        bondingCurve = vm.envAddress("GTE_SIMPLE_BONDING_CURVE_TESTNET");

        vm.createSelectFork("testnet");

        _;
    }

    /*//////////////////////////////////////////////////////////////
                                  SPOT
    //////////////////////////////////////////////////////////////*/

    // struct LaunchpadSlots {
    //     bytes32 quoteAsset;
    //     bytes32 bondingCurve;
    //     bytes32 eventNonce;
    //     bytes32 launchFee;
    // }

    // modifier UpgradeSafe//SimpleLaunchpadV0() {
    //     //SimpleLaunchpad sl = //SimpleLaunchpad(simpleLaunchpadProxy);

    //     vm.deal(address(this), 1 ether);
    //     address t = sl.launch{value: sl.launchFee()}("testName", "TN", "");
    //     address quote = address(sl.quoteAsset());
    //     LaunchpadSlots memory slotsBefore;
    //     LaunchpadSlots memory slotsAfter;

    //     // create state
    //     address token = _launchAndBuy();

    //     // cache before

    //     // launches[] is the 4th slot
    //     address l = simpleLaunchpadProxy;
    //     bytes32 $ = bytes32(uint256(4)).withKey(token);

    //     // Load launches fields individually
    //     //SimpleLaunchpad.LaunchData memory launchesBefore;
    //     bytes32 launchesSlot0 = vm.load(l, $.offset(0));
    //     launchesBefore.active = launchesSlot0.toBool();
    //     launchesBefore.bondingCurve = ISimpleBondingCurve((launchesSlot0 >> 8).toAddr());
    //     launchesBefore.quote = vm.load(l, $.offset(1)).toAddr();
    //     launchesBefore.__unallocated_field_0 = vm.load(l, $.offset(2)).toU256();
    //     launchesBefore.__unallocated_field_1 = vm.load(l, $.offset(3)).toU256();
    //     launchesBefore.baseSoldFromCurve = vm.load(l, $.offset(4)).toU256();
    //     launchesBefore.quoteBoughtByCurve = vm.load(l, $.offset(5)).toU256();

    //     // Load rest of sate with getters
    //     slotsBefore.bondingCurve = captureStateHash(address(sl), abi.encodeWithSignature("bondingCurve()"));
    //     slotsBefore.quoteAsset = captureStateHash(address(sl), abi.encodeWithSignature("quoteAsset()"));
    //     slotsBefore.eventNonce = captureStateHash(address(sl), abi.encodeWithSignature("eventNonce()"));
    //     slotsBefore.launchFee = captureStateHash(address(sl), abi.encodeWithSignature("launchFee()"));

    //     // upgrade
    //     address launchpadLogic = address(new //SimpleLaunchpad(uniV2Router, gteRouterProxy, clobManagerProxy));
    //     vm.prank(factory.adminOf(simpleLaunchpadProxy));
    //     factory.upgrade(simpleLaunchpadProxy, launchpadLogic);

    //     // cache after
    //     //SimpleLaunchpad.LaunchData memory launchesAfter = sl.launches(token);
    //     slotsAfter.bondingCurve = captureStateHash(address(sl), abi.encodeWithSignature("bondingCurve()"));
    //     slotsAfter.quoteAsset = captureStateHash(address(sl), abi.encodeWithSignature("quoteAsset()"));
    //     slotsAfter.eventNonce = captureStateHash(address(sl), abi.encodeWithSignature("eventNonce()"));
    //     slotsAfter.launchFee = captureStateHash(address(sl), abi.encodeWithSignature("launchFee()"));

    //     // validate
    //     bool launchesSafe = launchesBefore.active == launchesAfter.active
    //         && launchesBefore.bondingCurve == launchesAfter.bondingCurve && launchesBefore.quote == launchesAfter.quote
    //         && launchesBefore.__unallocated_field_0 == launchesAfter.__unallocated_field_0
    //         && launchesBefore.__unallocated_field_1 == launchesAfter.__unallocated_field_1
    //         && launchesBefore.baseSoldFromCurve == launchesAfter.baseSoldFromCurve
    //         && launchesBefore.quoteBoughtByCurve == launchesAfter.quoteBoughtByCurve;

    //     assertTrue(launchesSafe, "LaunchData struct or launches[] storage position fucked");
    //     assertEq(slotsBefore.bondingCurve, slotsAfter.bondingCurve, "bondingCurve slot fucked");
    //     assertEq(slotsBefore.quoteAsset, slotsAfter.quoteAsset, "quoteAsset slot fucked");
    //     assertEq(slotsBefore.eventNonce, slotsAfter.eventNonce, "eventNonce slot fucked");
    //     assertEq(slotsBefore.launchFee, slotsAfter.launchFee, "launchFee slot fucked");

    //     console.log("//SimpleLaunchpad storage safe for upgrade...");

    //     _;
    // }

    // CLOBManagerStorage private cmStorage;

    // modifier UpgradeSafeCLOBManager() {
    //     CLOBManager cm = CLOBManager(clobManagerProxy);

    //     address operator = vm.randomAddress();
    //     (address base, address quote, address userA, address userB, ICLOB clob) = _launchAndTradeClob(operator);

    //     // cache state before

    //     // @todo add getters for fee data and token pair hash
    //     // cmStorage.feeData.totalFees[base] = cm.getTotalFees(base);
    //     // cmStorage.feeData.totalFees[quote] = cm.getTotalFees(quote);
    //     // cmStorage.feeData.unclaimedFees[base] = cm.getUnclaimedFees(base);
    //     // cmStorage.feeData.unclaimedFees[quote] = cm.getUnclaimedFees(quote);
    //     // cmStorage.tokenPairHash[tokenPairHash] = address(clob);

    //     cmStorage.eventNonce = cm.getEventNonce();
    //     cmStorage.feeData.feeRecipient = cm.getFeeRecipient();
    //     cmStorage.feeData.accountFeeTier[userA] = cm.getFeeTier(userA);
    //     cmStorage.feeData.accountFeeTier[userB] = cm.getFeeTier(userB);
    //     cmStorage.isCLOB[address(clob)] = true;
    //     cmStorage.operatorRoleApprovals[userA][operator] = cm.getOperatorRoleApprovals(userA, operator);
    //     cmStorage.operatorRoleApprovals[userB][operator] = cm.getOperatorRoleApprovals(userB, operator);
    //     cmStorage.accountTokenBalances[userA][base] = cm.getAccountBalance(userA, base);
    //     cmStorage.accountTokenBalances[userA][quote] = cm.getAccountBalance(userA, quote);
    //     cmStorage.accountTokenBalances[userB][base] = cm.getAccountBalance(userB, base);
    //     cmStorage.accountTokenBalances[userB][quote] = cm.getAccountBalance(userB, quote);

    //     // upgrade
    //     uint16[] memory makerFees = new uint16[](1);
    //     uint16[] memory takerFees = new uint16[](1);
    //     address clobManagerLogic = address(new CLOBManager(address(beacon), 2_147_483_647, makerFees, takerFees));
    //     vm.prank(factory.adminOf(clobManagerProxy));
    //     factory.upgrade(clobManagerProxy, clobManagerLogic);

    //     // validate
    //     string memory c = "CLOBManager";
    //     string memory e = "state mapping changed!";

    //     assertEq(cmStorage.eventNonce, cm.getEventNonce(), err(c, "event nonce", e));
    //     assertEq(cmStorage.feeData.feeRecipient, cm.getFeeRecipient(), err(c, "fee recipient", e));
    //     assertEq(
    //         uint8(cmStorage.feeData.accountFeeTier[userA]), uint8(cm.getFeeTier(userA)), err(c, "account fee tier", e)
    //     );
    //     assertEq(
    //         uint8(cmStorage.feeData.accountFeeTier[userB]), uint8(cm.getFeeTier(userB)), err(c, "account fee tier", e)
    //     );
    //     assertEq(cmStorage.isCLOB[address(clob)], cm.isMarket(address(clob)), err(c, "is clob", e));
    //     assertEq(
    //         cmStorage.operatorRoleApprovals[userA][operator],
    //         cm.getOperatorRoleApprovals(userA, operator),
    //         err(c, "operator approvals", e)
    //     );
    //     assertEq(
    //         cmStorage.operatorRoleApprovals[userB][operator],
    //         cm.getOperatorRoleApprovals(userB, operator),
    //         err(c, "operator approvals", e)
    //     );
    //     assertEq(
    //         cmStorage.accountTokenBalances[userA][base],
    //         cm.getAccountBalance(userA, base),
    //         err(c, "account balances", e)
    //     );
    //     assertEq(
    //         cmStorage.accountTokenBalances[userA][quote],
    //         cm.getAccountBalance(userA, quote),
    //         err(c, "account balances", e)
    //     );
    //     assertEq(
    //         cmStorage.accountTokenBalances[userB][base],
    //         cm.getAccountBalance(userB, base),
    //         err(c, "account balances", e)
    //     );
    //     assertEq(
    //         cmStorage.accountTokenBalances[userB][quote],
    //         cm.getAccountBalance(userB, quote),
    //         err(c, "account balances", e)
    //     );

    //     console.log("CLOBManager storage safe for upgrade...");
    //     _;
    // }

    // Book private cStorage;
    // MarketConfig private configBefore;
    // MarketConfig private configAfter;

    // MarketSettings private settingsBefore;
    // MarketSettings private settingsAfter;

    // MarketMetadata private metadataBefore;
    // MarketMetadata private metadataAfter;

    // /// @dev Struct ordering state assertions produce false negatives if entire structs are read, rather than individual fields,
    // /// So for individual members that dont have getters, they should be loaded directly using the struct's slot, offset, and optionally key(s)
    // modifier UpgradeSafeCLOBV0() {
    //     CLOBManager cm = CLOBManager(clobManagerProxy);
    //     address operator = vm.randomAddress();

    //     (address base, address quote, address userA, address userB, ICLOB clob) = _launchAndTradeClob(operator);

    //     address c = address(clob);
    //     bytes32 $ = SpotStorageLib.CLOB_STORAGE_POSITION;

    //     // Load each field of the config struct
    //     configBefore.factory = vm.load(c, $.offset(0)).toAddr();
    //     configBefore.maxNumOrders = vm.load(c, $.offset(1)).toU256();
    //     configBefore.quoteToken = IERC20(vm.load(c, $.offset(2)).toAddr());
    //     configBefore.baseToken = IERC20(vm.load(c, $.offset(3)).toAddr());
    //     configBefore.quoteSize = vm.load(c, $.offset(4)).toU256();
    //     configBefore.baseSize = vm.load(c, $.offset(5)).toU256();

    //     // Load each field of the settings struct
    //     bytes32 settingSlot0 = vm.load(c, $.offset(6));
    //     settingsBefore.status = (settingSlot0 & bytes32(uint256(1))).toBool();
    //     settingsBefore.maxLimitsPerTx = (settingSlot0 >> 8).toU8();
    //     settingsBefore.minLimitOrderAmountInBase = vm.load(c, $.offset(7)).toU256();
    //     settingsBefore.tickSize = vm.load(c, $.offset(8)).toU256();

    //     // Load each field of the metadata struct
    //     metadataBefore.orderIdCounter = uint96(clob.getNextOrderId()) - 1;
    //     metadataBefore.numBids = clob.getNumBids();
    //     metadataBefore.numAsks = clob.getNumAsks();
    //     (metadataBefore.quoteTokenOpenInterest, metadataBefore.baseTokenOpenInterest) = clob.getOpenInterest();
    //     metadataBefore.eventNonce = clob.getEventNonce();

    //     // Load each field of the Order struct
    //     // One order is left on the book after _launchAndTradeClob
    //     // Set the storage pointer to the order struct (orders osset is 17 and key is the latest orderId in metadata)
    //     $ = $.offset(17).withKey(uint256(metadataBefore.orderIdCounter));

    //     Order memory openOrder;
    //     // SLOT 0 //
    //     bytes32 orderSlot0 = vm.load(c, $.offset(0));
    //     openOrder.side = Side(orderSlot0.toU8());
    //     openOrder.cancelTimestamp = orderSlot0.shiftR(BOOL).toU32();
    //     // remaining slots
    //     openOrder.id = OrderIdLib.wrap(vm.load(c, $.offset(1)).toU256());
    //     openOrder.prevOrderId = OrderIdLib.wrap(vm.load(c, $.offset(2)).toU256());
    //     openOrder.nextOrderId = OrderIdLib.wrap(vm.load(c, $.offset(3)).toU256());
    //     openOrder.owner = vm.load(c, $.offset(4)).toAddr();
    //     openOrder.price = vm.load(c, $.offset(5)).toU256();
    //     openOrder.amount = vm.load(c, $.offset(6)).toU256();

    //     // Load each field of the openOrder's Limit
    //     // Set the storage pointer to the limit struct
    //     // (offset depends on if bidLimits or askLimits, key is the openOrder's price)
    //     {
    //         uint256 limitsOffset = openOrder.side == Side.BUY ? 18 : 19;
    //         $ = SpotStorageLib.CLOB_STORAGE_POSITION.offset(limitsOffset);
    //         $ = $.withKey(openOrder.price);
    //     }

    //     Limit memory limitBefore;
    //     limitBefore.numOrders = vm.load(c, $.offset(0)).toU64();
    //     limitBefore.headOrder = OrderIdLib.wrap(vm.load(c, $.offset(1)).toU256());
    //     limitBefore.tailOrder = OrderIdLib.wrap(vm.load(c, $.offset(2)).toU256());

    //     // upgrade
    //     address clobLogic = address(new CLOB(gteRouterProxy));
    //     vm.prank(beacon.owner());
    //     beacon.upgradeTo(clobLogic);

    //     // validate
    //     string memory n = "CLOB";
    //     string memory e = "state mapping changed!";

    //     // MarketConfig struct check
    //     {
    //         configAfter = clob.getMarketConfig();

    //         bool marketConfigSafe = configBefore.factory == configAfter.factory
    //             && configBefore.maxNumOrders == configAfter.maxNumOrders
    //             && address(configBefore.baseToken) == address(configAfter.baseToken)
    //             && address(configBefore.quoteToken) == address(configAfter.quoteToken)
    //             && configBefore.baseSize == configAfter.baseSize && configBefore.quoteSize == configAfter.quoteSize;

    //         assertTrue(marketConfigSafe, err(n, "MarketConfig struct or position", e));
    //     }

    //     // MarketSettings struct check
    //     {
    //         settingsAfter = clob.getMarketSettings();

    //         bool marketSettingsSafe = settingsBefore.status == settingsAfter.status
    //             && settingsBefore.maxLimitsPerTx == settingsAfter.maxLimitsPerTx
    //             && settingsBefore.minLimitOrderAmountInBase == settingsAfter.minLimitOrderAmountInBase
    //             && settingsBefore.tickSize == settingsAfter.tickSize;

    //         assertTrue(marketSettingsSafe, err(n, "MarketSettings struct or position", e));
    //     }

    //     // MarketMetadata struct check
    //     {
    //         // todo add MarketMetadata getter to clob
    //         (uint256 quoteOI, uint256 baseOI) = clob.getOpenInterest();
    //         bool metadataSafe = metadataBefore.orderIdCounter == uint96(clob.getNextOrderId()) - 1
    //             && metadataBefore.numBids == clob.getNumBids() && metadataBefore.numAsks == clob.getNumAsks()
    //             && metadataBefore.baseTokenOpenInterest == baseOI && metadataBefore.quoteTokenOpenInterest == quoteOI
    //             && metadataBefore.eventNonce == clob.getEventNonce();

    //         assertTrue(metadataSafe, err(n, "MarketMetadata struct or position", e));
    //     }

    //     {
    //         Order memory orderAfter = clob.getOrder(OrderIdLib.unwrap(openOrder.id));

    //         bool orderSafe = uint8(orderAfter.side) == uint8(openOrder.side)
    //             && orderAfter.cancelTimestamp == openOrder.cancelTimestamp
    //             && OrderIdLib.unwrap(orderAfter.id) == OrderIdLib.unwrap(openOrder.id)
    //             && OrderIdLib.unwrap(orderAfter.prevOrderId) == OrderIdLib.unwrap(openOrder.prevOrderId)
    //             && OrderIdLib.unwrap(orderAfter.nextOrderId) == OrderIdLib.unwrap(openOrder.nextOrderId)
    //             && orderAfter.owner == openOrder.owner && orderAfter.amount == openOrder.amount
    //             && orderAfter.amount == openOrder.amount;

    //         assertTrue(orderSafe, err(n, "Order struct or position", e));
    //     }

    //     {
    //         Limit memory limitAfter = clob.getLimit(openOrder.price, openOrder.side);
    //         bool limitSafe = limitBefore.numOrders == limitAfter.numOrders
    //             && limitBefore.headOrder.eq(limitAfter.headOrder) && limitBefore.tailOrder.eq(limitAfter.tailOrder);

    //         assertTrue(limitSafe, err(n, "Limit struct or position", e));
    //     }

    //     console.log("CLOB storage safe for upgrade...");

    //     _;
    // }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    function err(string memory contractName, string memory stateName, string memory message)
        internal
        pure
        returns (string memory m)
    {
        m = contractName.concat(" ").concat(stateName).concat(" ").concat(message);
    }

    function captureStateHash(address target, bytes memory data) internal view returns (bytes32) {
        (bool success, bytes memory output) = target.staticcall(data);
        require(success, "call failed");

        return keccak256(output);
    }

    function setState(address target, bytes32[] memory stateHashes) internal {
        for (uint256 i = 0; i < stateHashes.length; i++) {
            if (stateHashes[i] == bytes32(0)) continue;

            vm.store(target, bytes32(i), stateHashes[i]);
        }
    }

    function bytes32AddressCrop(bytes32 x) internal pure returns (bytes32) {
        return (x << 96) >> 96;
    }

    // function _launchAndBuy() internal returns (address token) {
    //     //SimpleLaunchpad sl = //SimpleLaunchpad(simpleLaunchpadProxy);
    //     address quote = address(sl.currentQuoteAsset());

    //     quote.safeApprove(address(sl), 10 ether);

    //     vm.deal(address(this), 100 ether);
    //     deal(quote, address(this), 100 ether);

    //     token = sl.launch{value: sl.launchFee()}("testName", "TN", "");

    //     uint256 baseAmount = sl.quoteBaseForQuote(token, 10 ether, true);

    //     ILaunchpad.BuyData memory b = ILaunchpad.BuyData({
    //         account: address(this),
    //         token: token,
    //         recipient: address(this),
    //         amountOutBase: baseAmount,
    //         maxAmountInQuote: type(uint256).max
    //     });

    //     sl.buy(b);
    // }

    function _launchAndTradeClob(address operator)
        internal
        returns (address base, address quote, address userA, address userB, ICLOB clob)
    {
        CLOBManager cm = CLOBManager(clobManagerProxy);
        Operator o = Operator(operatorProxy);

        userA = vm.randomAddress();
        userB = vm.randomAddress();

        address clobOwner = cm.owner();

        SettingsParams memory settings;
        settings.owner = clobOwner;
        settings.maxLimitsPerTx = 10;
        settings.minLimitOrderAmountInBase = 1 ether / 1000;
        settings.tickSize = 1 ether / 10_000;

        MockERC20 b = new MockERC20();
        b.initialize("base token", "bt", 18);

        MockERC20 q = new MockERC20();
        q.initialize("quote token", "qt", 18);

        base = address(b);
        quote = address(q);

        deal(base, userA, 1000 ether);
        deal(quote, userB, 1000 ether);

        vm.startPrank(cm.owner());
        clob = ICLOB(cm.createMarket(base, quote, settings));
        {
            address[] memory accounts = new address[](2);
            FeeTiers[] memory feeTiers = new FeeTiers[](2);

            accounts[0] = userA;
            accounts[1] = userB;
            feeTiers[0] = FeeTiers.ONE;
            feeTiers[1] = FeeTiers.ONE;
            cm.setAccountFeeTiers(accounts, feeTiers);
        }
        vm.stopPrank();

        vm.startPrank(userA);

        b.approve(address(cm), 1000 ether);
        cm.accountManager().deposit(userA, base, 1000 ether);
        o.approveOperator(operator, 1 << uint256(OperatorRoles.CLOB_LIMIT));

        vm.stopPrank();

        ICLOB.PostLimitOrderArgs memory args0 = ICLOB.PostLimitOrderArgs({
            amountInBase: 10 ether,
            price: 1 ether, // 1:1
            cancelTimestamp: uint32(block.timestamp),
            side: Side.SELL,
            clientOrderId: 0,
            limitOrderType: ICLOB.LimitOrderType.POST_ONLY
        });

        vm.prank(operator);
        clob.postLimitOrder(userA, args0);

        vm.startPrank(userB);

        q.approve(address(cm), 1000 ether);
        cm.accountManager().deposit(userB, quote, 1000 ether);
        o.approveOperator(operator, 1 << uint256(OperatorRoles.CLOB_FILL));

        vm.stopPrank();

        ICLOB.PostFillOrderArgs memory args1 = ICLOB.PostFillOrderArgs({
            amount: 10 ether,
            priceLimit: 1 ether,
            side: Side.BUY,
            amountIsBase: false,
            fillOrderType: ICLOB.FillOrderType.IMMEDIATE_OR_CANCEL
        });

        vm.prank(operator);
        clob.postFillOrder(userB, args1);

        // Leave an order resting on the book for clob state assertions
        args0 = ICLOB.PostLimitOrderArgs({
            amountInBase: 10 ether,
            price: 1 ether, // 1:1
            cancelTimestamp: uint32(block.timestamp),
            side: Side.SELL,
            clientOrderId: 0,
            limitOrderType: ICLOB.LimitOrderType.POST_ONLY
        });

        vm.prank(operator);
        clob.postLimitOrder(userA, args0);
    }
}

library StorageReaderLib {
    using StorageReaderLib for bytes32;

    uint256 public constant U8 = 8;
    uint256 public constant BOOL = 8;
    uint256 public constant U32 = 32;

    function offset(bytes32 slot, uint256 o) internal pure returns (bytes32) {
        return bytes32(uint256(slot) + o);
    }

    function withKey(bytes32 slot, bytes32 key) internal pure returns (bytes32) {
        return keccak256(abi.encode(key, slot));
    }

    function withKey(bytes32 slot, address key) internal pure returns (bytes32) {
        return withKey(slot, bytes32(uint256(uint160(key))));
    }

    function withKey(bytes32 slot, uint256 key) internal pure returns (bytes32) {
        return withKey(slot, bytes32(key));
    }

    function toAddr(bytes32 value) internal pure returns (address) {
        return address(uint160(uint256(value)));
    }

    function toU256(bytes32 value) internal pure returns (uint256) {
        return uint256(value);
    }

    function toU64(bytes32 value) internal pure returns (uint64) {
        return uint64(uint256(value));
    }

    function toU32(bytes32 value) internal pure returns (uint32) {
        return uint32(uint256(value));
    }

    function toU8(bytes32 value) internal pure returns (uint8) {
        return uint8(uint256(value));
    }

    function toBool(bytes32 value) internal pure returns (bool) {
        return value & bytes32(uint256(1)) > 0;
    }

    function shiftR(bytes32 value, uint256[2] memory shifts) internal pure returns (bytes32) {
        return value.shiftR(shifts[0]).shiftR(shifts[1]);
    }

    function shiftR(bytes32 value, uint256 shiftBy) internal pure returns (bytes32) {
        return value >> shiftBy;
    }
}

library ScriptProtectorLib {
    function toAddressCrop(bytes32 x) internal pure returns (bytes32) {
        return (x << 96) >> 96;
    }
}
