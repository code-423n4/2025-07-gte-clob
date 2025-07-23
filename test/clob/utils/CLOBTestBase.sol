// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {ERC20Harness} from "test/harnesses/ERC20Harness.sol";
import {ICLOB} from "contracts/clob/ICLOB.sol";
import {CLOB} from "contracts/clob/CLOB.sol";
import {CLOBManager} from "contracts/clob/CLOBManager.sol";
import {ICLOBManager, ConfigParams, SettingsParams} from "contracts/clob/ICLOBManager.sol";
import {Side} from "contracts/clob/types/Order.sol";
import {MarketConfig} from "contracts/clob/types/Book.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {UpgradeableBeacon} from "@openzeppelin/proxy/beacon/UpgradeableBeacon.sol";
import {IERC20, ERC20} from "@openzeppelin/token/ERC20/ERC20.sol";
import {ERC1967Factory} from "@solady/utils/ERC1967Factory.sol";
import {AccountManager} from "contracts/account-manager/AccountManager.sol";
import {Test, console} from "forge-std/Test.sol";
contract CLOBTestBase is Test {
    using FixedPointMathLib for uint256;
    ERC1967Factory public factory;
    CLOBManager public clobManager;
    AccountManager public accountManager;
    address public clobBeacon;
    CLOB public clob;
    ERC20Harness public quoteToken;
    ERC20Harness public baseToken;
    address public dummyRouter = makeAddr("dummy router");
    // Mock market parameters
    uint256 constant MAX_PRICE = 1e18;
    uint256 constant MAX_AMOUNT = 1000 * 1e18;
    uint256 constant MAX_NUM_LIMITS_PER_SIDE = 1000;
    uint256 public constant QUOTE_TOKEN_SIZE = 1e18;
    uint256 public constant BASE_TOKEN_SIZE = 1e18;
    uint256 public constant TICK_SIZE = 0.0001 ether;
    uint256 public constant LOT_SIZE_IN_BASE = 0.01 ether;
    uint256 public constant MIN_LIMIT_ORDER_AMOUNT_IN_BASE = 0.005 ether;
    uint256 public constant TAKER_FEE_RATE_BASE = 5000; // 5 bps;
    uint256 public constant TAKER_FEE_RATE_ONE = 2500; // 2.5 bps;
    uint256 public constant MAKER_FEE_RATE_BASE = 3000; // 3 bps;
    uint256 public constant MAKER_FEE_RATE_ONE = 1500; // 1.5 bps;


    uint32 NOW = uint32(block.timestamp);
    uint32 NEVER = uint32(0);
    uint32 TOMORROW = uint32(block.timestamp + 1 days);


    // Users
    address[] public users;
    uint256 constant NUM_USERS = 5;
    event OrderCanceled(
        uint256 indexed eventNonce,
        uint256 indexed orderId,
        address indexed owner,
        uint256 quoteTokenRefunded,
        uint256 baseTokenRefunded,
        ICLOB.CancelType context
    );
    function setUp() public virtual {
        // Deploy tokens
        quoteToken = new ERC20Harness("Quote Token", "QT");
        baseToken = new ERC20Harness("Base Token", "BT");
        factory = new ERC1967Factory();
        vm.label(dummyRouter, "dummy router");

        _deployProxiesAndImplementations();

        clob = CLOB(deployClob());
        // Create users and allocate tokens
        for (uint256 i = 0; i < NUM_USERS; i++) {
            address user = vm.addr(i + 1);
            users.push(user);
            // Ignore max limits per tx
            _setMaxLimitWhitelist(user, true);
        }
    }
    ConfigParams public params;
    SettingsParams public settings;
    function deployClob() internal returns (address clobAddress) {
        // Max limits defaults to 1 if passed as 0
        settings = SettingsParams({
            owner: address(this),
            maxLimitsPerTx: 2,
            minLimitOrderAmountInBase: MIN_LIMIT_ORDER_AMOUNT_IN_BASE,
            tickSize: TICK_SIZE,
            lotSizeInBase: 1
        });
        // Create the market using the clobManager
        clobAddress = clobManager.createMarket(address(baseToken), address(quoteToken), settings);
    }
    function quoteTokenAmount(uint256 price, uint256 amountInBase) public pure returns (uint256) {
        return (amountInBase * price) / BASE_TOKEN_SIZE;
    }
    function baseTokenAmount(uint256 price, uint256 amountInQuote) public pure returns (uint256) {
        return (amountInQuote * BASE_TOKEN_SIZE) / price;
    }
    function getTakerFee(address account, uint256 amount) public view returns (uint256) {
        uint256 feeRate = accountManager.getSpotTakerFeeRateForTier(accountManager.getFeeTier(account));
        return amount.fullMulDiv(feeRate, 10_000_000);
    }
    function getMakerFee(address account, uint256 amount) public view returns (uint256) {
        uint256 feeRate = accountManager.getSpotMakerFeeRateForTier(accountManager.getFeeTier(account));
        return amount.fullMulDiv(feeRate, 10_000_000);
    }
    /// @notice Setup tokens for a user based on the side
    function setupTokens(
        Side side,
        address user,
        uint256 amount,
        uint256 price,
        bool amountIsBase
    ) public returns (uint256) {
        vm.startPrank(user);
        // SetupTokens is used for accurate accounting of token balances and allowances.
        // If the allowance is already at max, we need to reset it to 0 before approving again
        // to avoid excessive approvals.
        if (quoteToken.allowance(user, address(accountManager)) == type(uint256).max) {
            quoteToken.approve(address(accountManager), 0);
        }
        if (baseToken.allowance(user, address(accountManager)) == type(uint256).max) {
            baseToken.approve(address(accountManager), 0);
        }
        // Deposit or mint tokens based on the side
        uint256 amountDeposited;
        if (side == Side.BUY) {
            // Deposit quote tokens into the CLOB contract
            uint256 depositAmount = amountIsBase ? quoteTokenAmount(price, amount) : amount;
            quoteToken.mint(user, depositAmount);
            quoteToken.approve(address(accountManager), depositAmount);
            clobManager.accountManager().deposit(user, address(quoteToken), depositAmount);
            amountDeposited = depositAmount;
        } else {
            // Deposit base tokens into the CLOB contract
            uint256 depositAmount = amountIsBase ? amount : baseTokenAmount(price, amount);
            baseToken.mint(user, depositAmount);
            baseToken.approve(address(accountManager), depositAmount);
            clobManager.accountManager().deposit(user, address(baseToken), depositAmount);
            amountDeposited = depositAmount;
        }
        vm.stopPrank();
        return amountDeposited;
    }
    function _setMaxLimitWhitelist(address who, bool toggle) internal {
        vm.prank(clob.owner());
        address[] memory accounts = new address[](1);
        bool[] memory toggles = new bool[](1);
        accounts[0] = who;
        toggles[0] = toggle;
        clobManager.setMaxLimitsExempt(accounts, toggles);
    }

    uint32 setupOrderExpiry = NEVER;

    function setupOrder(Side side, address user, uint256 amountInBase, uint256 price)
        public
    {
        setupTokens(side, user, amountInBase, price, true);
        // Post a limit order
        ICLOB.PostLimitOrderArgs memory args = ICLOB.PostLimitOrderArgs({
            amountInBase: amountInBase,
            clientOrderId: 0,
            price: price,
            cancelTimestamp: setupOrderExpiry,
            side: side,
            limitOrderType: ICLOB.LimitOrderType.GOOD_TILL_CANCELLED
        });
        vm.prank(user);
        clob.postLimitOrder(user, args);
    }
    function assertTokenBalance(address user, Side side, uint256 expectedBalance)
        public
        view
    {
        if (side == Side.BUY) {
            assertEq(
                clobManager.accountManager().getAccountBalance(user, address(baseToken)),
                expectedBalance,
                "Base account balance should match"
            );
        } else {
            assertEq(
                clobManager.accountManager().getAccountBalance(user, address(quoteToken)),
                expectedBalance,
                "Quote account balance should match"
            );
        }
    }
    function computeMatchQuantities(
        Side side,
        uint256 amount,
        uint256 matchedBase,
        uint256 price,
        address taker,
        address maker,
        bool denominatedInBase
    ) public view returns (MatchQuantities memory matchedQuantities) {
        uint256 incomingBase = denominatedInBase ? amount : baseTokenAmount(price, amount);
        matchedBase = incomingBase > matchedBase ? matchedBase : incomingBase;
        matchedQuantities.matchedQuote = quoteTokenAmount(matchedBase, price);
        matchedQuantities.matchedBase = matchedBase;
        matchedQuantities.takerFeeInQuote = getTakerFee(taker, matchedQuantities.matchedQuote);
        matchedQuantities.takerFeeInBase = getTakerFee(taker, matchedQuantities.matchedBase);
        matchedQuantities.makerFeeInQuote = getMakerFee(maker, matchedQuantities.matchedQuote);
        matchedQuantities.makerFeeInBase = getMakerFee(maker, matchedQuantities.matchedBase);
        if (side == Side.BUY) matchedQuantities.postedQuoteInBase = denominatedInBase ? amount - matchedBase : 0;
        else matchedQuantities.postedBase = denominatedInBase ? amount - matchedBase : 0;
    }

    function _deployProxiesAndImplementations() internal {
        uint16[] memory makerFees = new uint16[](2);
        uint16[] memory takerFees = new uint16[](2);
        makerFees[0] = uint16(MAKER_FEE_RATE_BASE);
        makerFees[1] = uint16(MAKER_FEE_RATE_ONE);
        takerFees[0] = uint16(TAKER_FEE_RATE_BASE);
        takerFees[1] = uint16(TAKER_FEE_RATE_ONE);

        // Step 1: Deploy AccountManager proxy with temporary implementation
        address tempAccountManagerImpl = address(new AccountManager(dummyRouter, address(0), makerFees, takerFees));
        accountManager = AccountManager(
            factory.deployAndCall(
                tempAccountManagerImpl,
                address(this),
                abi.encodeCall(AccountManager.initialize, (address(this)))
            )
        );

        // Step 2: Create CLOB implementation with temporary factory address
        CLOB tempClobImplementation = new CLOB(address(0), dummyRouter, address(accountManager), MAX_NUM_LIMITS_PER_SIDE);
        clobBeacon = address(new UpgradeableBeacon(address(tempClobImplementation), address(this)));

        // Step 3: Deploy CLOBManager proxy
        address tempClobManagerImpl = address(new CLOBManager(clobBeacon, address(accountManager)));
        clobManager = CLOBManager(
            factory.deployAndCall(
                tempClobManagerImpl,
                address(this),
                abi.encodeCall(CLOBManager.initialize, (address(this)))
            )
        );

        // Step 4: Upgrade AccountManager with correct CLOBManager address
        address correctAccountManagerImpl = address(new AccountManager(dummyRouter, address(clobManager), makerFees, takerFees));
        factory.upgrade(address(accountManager), correctAccountManagerImpl);

        // Step 5: Update beacon with correct CLOB implementation
        CLOB correctClobImplementation = new CLOB(address(clobManager), dummyRouter, address(accountManager), MAX_NUM_LIMITS_PER_SIDE);
        UpgradeableBeacon(clobBeacon).upgradeTo(address(correctClobImplementation));
    }
}
struct MatchQuantities {
    uint256 matchedBase;
    /// Amount of quote token actually traded
    uint256 matchedQuote;
    /// Amount of quote token posted after matching
    uint256 postedQuoteInBase;
    /// Amount of base token posted after matching
    uint256 postedBase;
    /// Amount of fees paid in base
    uint256 takerFeeInBase;
    /// Amount of fees paid in quote atoms
    uint256 takerFeeInQuote;
    uint256 makerFeeInQuote;
    uint256 makerFeeInBase;
}
