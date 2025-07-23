# Report


## Gas Optimizations


| |Issue|Instances|
|-|:-|:-:|
| [GAS-1](#GAS-1) | `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings) | 14 |
| [GAS-2](#GAS-2) | Using bools for storage incurs overhead | 3 |
| [GAS-3](#GAS-3) | Cache array length outside of loop | 8 |
| [GAS-4](#GAS-4) | For Operations that will not overflow, you could use unchecked | 208 |
| [GAS-5](#GAS-5) | Functions guaranteed to revert when called by normal users can be marked `payable` | 19 |
| [GAS-6](#GAS-6) | `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`) | 17 |
| [GAS-7](#GAS-7) | Using `private` rather than `public` for constants, saves gas | 3 |
| [GAS-8](#GAS-8) | Increments/decrements can be unchecked in for-loops | 10 |
| [GAS-9](#GAS-9) | Use != 0 instead of > 0 for unsigned integer comparison | 17 |
| [GAS-10](#GAS-10) | WETH address definition can be use directly | 1 |
### <a name="GAS-1"></a>[GAS-1] `a = a + b` is more gas effective than `a += b` for state variables (excluding arrays and mappings)
This saves **16 gas per instance.**

*Instances (14)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

270:                 totalQuoteMakerFee += currMakerFee;

274:                 totalBaseMakerFee += currMakerFee;

317:             self.accountTokenBalances[account][token] += amount;

324:             self.accountTokenBalances[account][token] += amount;

```

```solidity
File: ./contracts/clob/CLOB.sol

765:             totalQuoteSent += currMatch.quoteDelta;

766:             totalBaseReceived += currMatch.baseDelta;

799:             totalQuoteTokenReceived += currMatch.quoteDelta;

800:             totalBaseTokenSent += currMatch.baseDelta;

924:                 totalQuoteTokenRefunded += quoteTokenRefunded;

927:                 totalBaseTokenRefunded += baseTokenRefunded;

```

```solidity
File: ./contracts/clob/types/Book.sol

261:             self.metadata().quoteTokenOpenInterest += self.getQuoteTokenAmount(order.price, order.amount);

266:             self.metadata().baseTokenOpenInterest += order.amount;

```

```solidity
File: ./contracts/clob/types/FeeData.sol

128:         self.totalFees[token] += amount;

129:         self.unclaimedFees[token] += amount;

```

### <a name="GAS-2"></a>[GAS-2] Using bools for storage incurs overhead
Use uint256(1) and uint256(2) for true/false to avoid a Gwarmaccess (100 gas), and to avoid Gsset (20000 gas) when changing from ‘false’ to ‘true’, after having been ‘true’ in the past. See [source](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/58f635312aa21f947cae5f8578638a85aa2519f5/contracts/security/ReentrancyGuard.sol#L23-L27).

*Instances (3)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

19:     mapping(address market => bool) isMarket;

```

```solidity
File: ./contracts/clob/CLOBManager.sol

26:     mapping(address clob => bool) isCLOB;

28:     mapping(address account => bool) maxLimitWhitelist;

```

### <a name="GAS-3"></a>[GAS-3] Cache array length outside of loop
If not cached, the solidity compiler will always read the length of the array during each iteration. That is, if it is a storage array, this is an extra sload operation (100 additional extra gas for each iteration except for the first) and if it is a memory array, this is an extra mload operation (3 additional gas for each iteration except for the first).

*Instances (8)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

221:         for (uint256 i = 0; i < accounts.length; i++) {

263:         for (uint256 i; i < params.makerCredits.length; ++i) {

```

```solidity
File: ./contracts/clob/CLOBManager.sol

230:         for (uint256 i = 0; i < clobs.length; i++) {

243:         for (uint256 i = 0; i < clobs.length; i++) {

256:         for (uint256 i = 0; i < clobs.length; i++) {

279:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: ./contracts/clob/types/FeeData.sol

29:         for (uint256 i; i < fees.length; i++) {

```

```solidity
File: ./contracts/router/GTERouter.sol

275:         for (uint256 i = 0; i < hops.length; i++) {

```

### <a name="GAS-4"></a>[GAS-4] For Operations that will not overflow, you could use unchecked

*Instances (208)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

4: import {IAccountManager} from "./IAccountManager.sol";

5: import {ICLOB, MakerCredit} from "../clob/ICLOB.sol";

6: import {Side} from "../clob/types/Order.sol";

7: import {OperatorHelperLib} from "../utils/types/OperatorHelperLib.sol";

8: import {EventNonceLib as AccountEventNonce} from "../utils/types/EventNonce.sol";

9: import {Initializable} from "@solady/utils/Initializable.sol";

10: import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";

11: import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

12: import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";

13: import {Operator, OperatorRoles} from "../utils/Operator.sol";

14: import {FeeData, FeeDataLib, FeeDataStorageLib, PackedFeeRates, PackedFeeRatesLib, FeeTiers} from "../clob/types/FeeData.sol";

15: import {Roles} from "../clob/types/Roles.sol";

221:         for (uint256 i = 0; i < accounts.length; i++) {

243:             _creditAccount(self, params.taker, params.baseToken, params.takerBaseAmount - takerFee);

250:             _creditAccount(self, params.taker, params.quoteToken, params.takerQuoteAmount - takerFee);

263:         for (uint256 i; i < params.makerCredits.length; ++i) {

269:                 credit.quoteAmount -= currMakerFee;

270:                 totalQuoteMakerFee += currMakerFee;

273:                 credit.baseAmount -= currMakerFee;

274:                 totalBaseMakerFee += currMakerFee;

317:             self.accountTokenBalances[account][token] += amount;

324:             self.accountTokenBalances[account][token] += amount;

332:             self.accountTokenBalances[account][token] -= amount;

348:         keccak256(abi.encode(uint256(keccak256("AccountManagerStorage")) - 1)) & ~bytes32(uint256(0xff));

```

```solidity
File: ./contracts/account-manager/IAccountManager.sol

4: import {ICLOB, MakerCredit} from "../clob/ICLOB.sol";

5: import {OperatorRoles} from "../utils/Operator.sol";

6: import {FeeTiers} from "../clob/types/FeeData.sol";

```

```solidity
File: ./contracts/clob/CLOB.sol

5: import {ICLOB} from "./ICLOB.sol";

6: import {ICLOBManager} from "./ICLOBManager.sol";

7: import {IAccountManager} from "../account-manager/IAccountManager.sol";

8: import {CLOBStorageLib} from "./types/Book.sol";

9: import {TransientMakerData, MakerCredit} from "./types/TransientMakerData.sol";

10: import {Order, OrderLib, OrderId, OrderIdLib, Side} from "./types/Order.sol";

11: import {Book, BookLib, Limit, MarketConfig, MarketSettings} from "./types/Book.sol";

14: import {IOperator} from "contracts/utils/interfaces/IOperator.sol";

15: import {OperatorRoles} from "contracts/utils/Operator.sol";

16: import {OperatorHelperLib} from "contracts/utils/types/OperatorHelperLib.sol";

17: import {EventNonceLib as CLOBEventNonce} from "contracts/utils/types/EventNonce.sol";

20: import {SafeCastLib} from "@solady/utils/SafeCastLib.sol";

21: import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";

22: import {Ownable2StepUpgradeable} from "@openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

29:     using OrderLib for *;

271:         return OrderIdLib.getOrderId(address(0), _getStorage().metadata().orderIdCounter + 1);

449:             -totalQuoteSent.toInt256(),

455:             account, newOrder.id.unwrap(), -totalQuoteSent.toInt256(), totalBaseReceived.toInt256(), takerFee

479:             -baseSent.toInt256(),

484:             PostFillOrderResult(account, newOrder.id.unwrap(), quoteReceived.toInt256(), -baseSent.toInt256(), takerFee);

501:         if (postAmount + quoteTokenAmountSent + baseTokenAmountReceived == 0) revert ZeroOrder();

507:         uint256 eventNonce = CLOBEventNonce.inc(); // keep stack from blowing

510:             _settleIncomingOrder(ds, account, Side.BUY, quoteTokenAmountSent + postAmount, baseTokenAmountReceived);

517:             -quoteTokenAmountSent.toInt256(),

526:             -quoteTokenAmountSent.toInt256(),

542:         if (postAmount + quoteTokenAmountReceived + baseTokenAmountSent == 0) revert ZeroOrder();

548:         uint256 eventNonce = CLOBEventNonce.inc(); // Keep stack from blowing

551:             _settleIncomingOrder(ds, account, Side.SELL, quoteTokenAmountReceived, baseTokenAmountSent + postAmount);

559:             -baseTokenAmountSent.toInt256(),

568:             -baseTokenAmountSent.toInt256(),

665:             if (quoteTokenDelta + baseTokenDelta == 0) revert ZeroOrder();

696:             quoteTokenDelta -= postAmount.toInt256();

700:             baseTokenDelta -= postAmount.toInt256();

713:             quoteTokenDelta = oldAmountInQuote - newAmountInQuote;

716:                 uint256(ds.metadata().quoteTokenOpenInterest.toInt256() - quoteTokenDelta);

718:             baseTokenDelta = order.amount.toInt256() - amount.toInt256();

721:                 uint256(ds.metadata().baseTokenOpenInterest.toInt256() - baseTokenDelta);

763:             incomingOrder.amount -= currMatch.matchedAmount;

765:             totalQuoteSent += currMatch.quoteDelta;

766:             totalBaseReceived += currMatch.baseDelta;

797:             incomingOrder.amount -= currMatch.matchedAmount;

799:             totalQuoteTokenReceived += currMatch.quoteDelta;

800:             totalBaseTokenSent += currMatch.baseDelta;

819:             matchData.baseDelta = (matchedBase.min(takerOrder.amount) / lotSize) * lotSize;

825:                 (matchedBase.min(ds.getBaseTokenAmount(matchedPrice, takerOrder.amount)) / lotSize) * lotSize;

839:             if (!orderRemoved) ds.metadata().baseTokenOpenInterest -= matchData.baseDelta;

843:             if (!orderRemoved) ds.metadata().quoteTokenOpenInterest -= matchData.quoteDelta;

847:         else makerOrder.amount -= matchData.baseDelta;

908:         for (uint256 i = 0; i < numOrders; i++) {

914:                 continue; // Order may have been matched

924:                 totalQuoteTokenRefunded += quoteTokenRefunded;

927:                 totalBaseTokenRefunded += baseTokenRefunded;

969:             accountManager.debitAccount(maker, address(ds.config().quoteToken), uint256(-quoteTokenDelta));

975:             accountManager.debitAccount(maker, address(ds.config().baseToken), uint256(-baseTokenDelta));

```

```solidity
File: ./contracts/clob/CLOBManager.sol

5: import {CLOB, ICLOB} from "./CLOB.sol";

6: import {Side} from "./types/Order.sol";

7: import {Roles as CLOBRoles} from "./types/Roles.sol";

8: import {MakerCredit} from "./types/TransientMakerData.sol";

9: import {ICLOBManager, ConfigParams, SettingsParams} from "./ICLOBManager.sol";

10: import {FeeTiers} from "./types/FeeData.sol";

11: import {CLOBStorageLib, MarketConfig, MarketSettings, MIN_MIN_LIMIT_ORDER_AMOUNT_BASE} from "./types/Book.sol";

14: import {IAccountManager} from "../account-manager/IAccountManager.sol";

15: import {EventNonceLib as CLOBEventNonce} from "contracts/utils/types/EventNonce.sol";

18: import {Initializable} from "@solady/utils/Initializable.sol";

19: import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

20: import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";

21: import {OwnableRoles as CLOBAdminOwnableRoles} from "@solady/auth/OwnableRoles.sol";

22: import {IERC20Metadata} from "@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

23: import {BeaconProxy, IBeacon} from "@openzeppelin/proxy/beacon/BeaconProxy.sol";

36:         keccak256(abi.encode(uint256(keccak256("CLOBManagerStorage")) - 1)) & ~bytes32(uint256(0xff));

181:         config.quoteSize = 10 ** quoteDecimals;

182:         config.baseSize = 10 ** baseDecimals;

230:         for (uint256 i = 0; i < clobs.length; i++) {

243:         for (uint256 i = 0; i < clobs.length; i++) {

256:         for (uint256 i = 0; i < clobs.length; i++) {

279:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: ./contracts/clob/ICLOB.sol

4: import {Side, Order, OrderId} from "./types/Order.sol";

5: import {MarketConfig, MarketSettings, Limit} from "./types/Book.sol";

6: import {MakerCredit} from "./types/TransientMakerData.sol";

7: import {ICLOBManager} from "./ICLOBManager.sol";

39:         uint32 cancelTimestamp; // unix timestamp after which the order is cancelled. Ignore if 0

41:         uint96 clientOrderId; // custom order id — id will be uint256(abi.encodePacked(account, clientOrderId))

48:         uint256 amountPostedInBase; // amount posted in baseLots

49:         int256 quoteTokenAmountTraded; // negative if outgoing, positive if incoming

50:         int256 baseTokenAmountTraded; // negative if outgoing, positive if incoming

65:         int256 quoteTokenAmountTraded; // negative if outgoing, positive if incoming

66:         int256 baseTokenAmountTraded; // negative if outgoing, positive if incoming

94:     function cancel(address account, CancelArgs memory args) external returns (uint256, uint256); // quoteToken refunded, baseToken refunded

```

```solidity
File: ./contracts/clob/ICLOBManager.sol

4: import {IAccountManager} from "../account-manager/IAccountManager.sol";

5: import {FeeTiers} from "./types/FeeData.sol";

6: import {ICLOB} from "./ICLOB.sol";

7: import {Side} from "./types/Order.sol";

8: import {MakerCredit} from "./types/TransientMakerData.sol";

```

```solidity
File: ./contracts/clob/ILimitLens.sol

4: import {ICLOB} from "./ICLOB.sol";

5: import {Limit} from "./types/Book.sol";

6: import {Order, Side} from "./types/Order.sol";

```

```solidity
File: ./contracts/clob/types/Book.sol

4: import {ICLOBManager} from "../ICLOBManager.sol";

6: import {RedBlackTree} from "./RedBlackTree.sol";

7: import {Side, Order, OrderLib, OrderId, OrderIdLib} from "./Order.sol";

9: import {EventNonceLib as BookEventNonce} from "contracts/utils/types/EventNonce.sol";

86:         keccak256(abi.encode(uint256(keccak256("TRANSIENT_MAX_LIMIT_ALLOWLIST")) - 1)) & ~bytes32(uint256(0xff));

90:         keccak256(abi.encode(uint256(keccak256("TRANSIENT_LIMITS_PLACED")) - 1)) & ~bytes32(uint256(0xff));

146:         return OrderIdLib.getOrderId(address(0), ++self.metadata().orderIdCounter);

195:             count++;

230:             counter++;

260:             self.metadata().numBids++;

261:             self.metadata().quoteTokenOpenInterest += self.getQuoteTokenAmount(order.price, order.amount);

265:             self.metadata().numAsks++;

266:             self.metadata().baseTokenOpenInterest += order.amount;

273:         limit.numOrders++;

290:             self.metadata().numBids--;

292:             self.metadata().quoteTokenOpenInterest -= self.getQuoteTokenAmount(order.price, order.amount);

294:             self.metadata().numAsks--;

296:             self.metadata().baseTokenOpenInterest -= order.amount;

318:         limit.numOrders--;

360:         keccak256(abi.encode(uint256(keccak256("CLOBStorage")) - 1)) & ~bytes32(uint256(0xff));

363:         keccak256(abi.encode(uint256(keccak256("MarketConfigStorage")) - 1)) & ~bytes32(uint256(0xff));

366:         keccak256(abi.encode(uint256(keccak256("MarketSettingsStorage")) - 1)) & ~bytes32(uint256(0xff));

369:         keccak256(abi.encode(uint256(keccak256("MarketMetadataStorage")) - 1)) & ~bytes32(uint256(0xff));

467:         return quoteAmount * self.config().baseSize / price;

476:         return baseAmount * price / self.config().baseSize;

```

```solidity
File: ./contracts/clob/types/FeeData.sol

4: import {EventNonceLib as FeeDataEventNonce} from "contracts/utils/types/EventNonce.sol";

6: import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

7: import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";

29:         for (uint256 i; i < fees.length; i++) {

30:             packedValue = packedValue | (uint256(fees[i]) << (i * U16_PER_WORD));

39:         uint256 shiftBits = index * U16_PER_WORD;

62:         keccak256(abi.encode(uint256(keccak256("FeeDataStorage")) - 1)) & ~bytes32(uint256(0xff));

128:         self.totalFees[token] += amount;

129:         self.unclaimedFees[token] += amount;

```

```solidity
File: ./contracts/clob/types/Order.sol

4: import {ICLOB} from "../ICLOB.sol";

48:     uint256 amount; // denominated in base for limit & either token for fill

```

```solidity
File: ./contracts/clob/types/RedBlackTree.sol

4: import {RedBlackTreeLib} from "@solady/utils/RedBlackTreeLib.sol";

51:         bytes32 result = RedBlackTreeLib.nearestAfter(tree.tree, nodeKey + 1);

61:         bytes32 result = RedBlackTreeLib.nearestBefore(tree.tree, nodeKey - 1);

```

```solidity
File: ./contracts/clob/types/Roles.sol

15:     uint256 constant ADMIN_ROLE = 1 << 0; // _ROLE_0

16:     uint256 constant MARKET_CREATOR = 1 << 1; // _ROLE_1

19:     uint256 constant FEE_COLLECTOR = 1 << 2; // _ROLE_2

20:     uint256 constant FEE_TIER_SETTER = 1 << 3; // _ROLE_3

21:     uint256 constant MAX_LIMITS_EXEMPT_SETTER = 1 << 4; // _ROLE_4

24:     uint256 constant TICK_SIZE_SETTER = 1 << 5; // _ROLE_5

25:     uint256 constant MAX_LIMITS_PER_TX_SETTER = 1 << 6; // _ROLE_6

26:     uint256 constant MIN_LIMIT_ORDER_AMOUNT_SETTER = 1 << 7; // _ROLE_7

```

```solidity
File: ./contracts/clob/types/TransientMakerData.sol

4: import {ICLOB} from "../ICLOB.sol";

15:         keccak256(abi.encode(uint256(keccak256("TransientMakers")) - 1)) & ~bytes32(uint256(0xff));

17:         keccak256(abi.encode(uint256(keccak256("TransientCredits")) - 1)) & ~bytes32(uint256(0xff));

28:         assembly ("memory-safe") {

55:         assembly ("memory-safe") {

87:         for (uint256 i; i < length; i++) {

97:         assembly ("memory-safe") {

112:         assembly ("memory-safe") {

126:                 tstore(add(dataSlot, i), 0) // clear maker

129:             mstore(0x40, add(memPointer, mul(len, 0x20))) // idk the purpose of this tbh

130:             tstore(slot, 0) // clear length

137:         assembly ("memory-safe") {

```

```solidity
File: ./contracts/router/GTERouter.sol

5: import {IUniswapV2Router01} from "./interfaces/IUniswapV2Router01.sol";

8: import {Side} from "contracts/clob/types/Order.sol";

9: import {IAccountManager, ICLOBManager} from "contracts/clob/ICLOBManager.sol";

10: import {ILaunchpad} from "contracts/launchpad/interfaces/ILaunchpad.sol";

11: import {ICLOB, MarketConfig} from "contracts/clob/ICLOB.sol";

14: import {IAllowanceTransfer} from "@permit2/interfaces/IAllowanceTransfer.sol";

17: import {WETH} from "@solady/tokens/WETH.sol";

18: import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

19: import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";

20: import {ReentrancyGuardTransient} from "@solady/utils/ReentrancyGuardTransient.sol";

275:         for (uint256 i = 0; i < hops.length; i++) {

277:             route.nextHopType = (i == hops.length - 1) ? HopType.NULL : hops[i + 1].getHopType();

307:         fillArgs.priceLimit = fillArgs.side == Side.BUY ? type(uint256).max : 0; // executeRoute enforced slippage at the end

318:             ? uint256(result.baseTokenAmountTraded) - result.takerFee

319:             : uint256(result.quoteTokenAmountTraded) - result.takerFee;

341:             0, // No amountOutMin since executeRoute enforces slippage

343:             address(this), // Always send to router

347:         tokenOut = path[path.length - 1];

348:         amountOut = amounts[amounts.length - 1];

352:         return (amounts[amounts.length - 1], tokenOut);

```

```solidity
File: ./contracts/utils/Operator.sol

4: import {EventNonceLib as OperatorEventNonce} from "./types/EventNonce.sol";

24:         keccak256(abi.encode(uint256(keccak256("OperatorStorage")) - 1)) & ~bytes32(uint256(0xff));

```

```solidity
File: ./contracts/utils/types/EventNonce.sol

16:         keccak256(abi.encode(uint256(keccak256("EventNonceStorage")) - 1)) & ~bytes32(uint256(0xff));

32:         return ++ds.eventNonce;

```

```solidity
File: ./contracts/utils/types/OperatorHelperLib.sol

4: import {IOperator} from "../interfaces/IOperator.sol";

5: import {OperatorRoles, OperatorStorage} from "../Operator.sol";

```

### <a name="GAS-5"></a>[GAS-5] Functions guaranteed to revert when called by normal users can be marked `payable`
If a function modifier such as `onlyOwner` is used, the function will revert if a normal user tries to pay the function. Marking the function as `payable` will lower the gas cost for legitimate callers because the compiler will not include checks for whether a payment was provided.

*Instances (19)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

166:     function deposit(address account, address token, uint256 amount) external virtual onlySenderOrOperator(account, OperatorRoles.SPOT_DEPOSIT) {

172:     function depositFromRouter(address account, address token, uint256 amount) external onlyGTERouter {

178:     function withdraw(address account, address token, uint256 amount) external virtual onlySenderOrOperator(account, OperatorRoles.SPOT_WITHDRAW) {

184:     function withdrawToRouter(address account, address token, uint256 amount) external onlyGTERouter {

194:     function registerMarket(address market) external onlyCLOBManager {

200:     function collectFees(address token, address feeRecipient) external virtual onlyOwnerOrRoles(Roles.FEE_COLLECTOR) returns (uint256 fee) {

211:     function setSpotAccountFeeTier(address account, FeeTiers feeTier) external virtual onlyCLOBManager {

217:     function setSpotAccountFeeTiers(address[] calldata accounts, FeeTiers[] calldata feeTiers) external virtual onlyCLOBManager {

231:     function settleIncomingOrder(ICLOB.SettleParams calldata params) external virtual onlyMarket returns (uint256 takerFee) {

297:     function creditAccount(address account, address token, uint256 amount) external virtual onlyMarket {

302:     function creditAccountNoEvent(address account, address token, uint256 amount) external virtual onlyMarket {

307:     function debitAccount(address account, address token, uint256 amount) external virtual onlyMarket {

```

```solidity
File: ./contracts/clob/CLOB.sol

311:     function setMaxLimitsPerTx(uint8 newMaxLimits) external onlyManager {

317:     function setTickSize(uint256 tickSize) external onlyManager {

323:     function setMinLimitOrderAmountInBase(uint256 newMinLimitOrderAmountInBase) external onlyManager {

329:     function setLotSizeInBase(uint256 newLotSizeInBase) external onlyManager {

```

```solidity
File: ./contracts/utils/types/OperatorHelperLib.sol

16:     function onlySenderOrOperator(IOperator operator, address gteRouter, address account, OperatorRoles requiredRole)

27:     function onlySenderOrOperator(IOperator operator, address account, OperatorRoles requiredRole) internal view {

35:     function onlySenderOrOperator(

```

### <a name="GAS-6"></a>[GAS-6] `++i` costs less gas compared to `i++` or `i += 1` (same for `--i` vs `i--` or `i -= 1`)
Pre-increments and pre-decrements are cheaper.

For a `uint256 i` variable, the following is true with the Optimizer enabled at 10k:

**Increment:**

- `i += 1` is the most expensive form
- `i++` costs 6 gas less than `i += 1`
- `++i` costs 5 gas less than `i++` (11 gas less than `i += 1`)

**Decrement:**

- `i -= 1` is the most expensive form
- `i--` costs 11 gas less than `i -= 1`
- `--i` costs 5 gas less than `i--` (16 gas less than `i -= 1`)

Note that post-increments (or post-decrements) return the old value before incrementing or decrementing, hence the name *post-increment*:

```solidity
uint i = 1;  
uint j = 2;
require(j == i++, "This will be false as i is incremented after the comparison");
```
  
However, pre-increments (or pre-decrements) return the new value:
  
```solidity
uint i = 1;  
uint j = 2;
require(j == ++i, "This will be true as i is incremented before the comparison");
```

In the pre-increment case, the compiler has to create a temporary variable (when used) for returning `1` instead of `2`.

Consider using pre-increments and pre-decrements where they are relevant (meaning: not where post-increments/decrements logic are relevant).

*Saves 5 gas per instance*

*Instances (17)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

221:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: ./contracts/clob/CLOB.sol

908:         for (uint256 i = 0; i < numOrders; i++) {

```

```solidity
File: ./contracts/clob/CLOBManager.sol

230:         for (uint256 i = 0; i < clobs.length; i++) {

243:         for (uint256 i = 0; i < clobs.length; i++) {

256:         for (uint256 i = 0; i < clobs.length; i++) {

279:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: ./contracts/clob/types/Book.sol

195:             count++;

230:             counter++;

260:             self.metadata().numBids++;

265:             self.metadata().numAsks++;

273:         limit.numOrders++;

290:             self.metadata().numBids--;

294:             self.metadata().numAsks--;

318:         limit.numOrders--;

```

```solidity
File: ./contracts/clob/types/FeeData.sol

29:         for (uint256 i; i < fees.length; i++) {

```

```solidity
File: ./contracts/clob/types/TransientMakerData.sol

87:         for (uint256 i; i < length; i++) {

```

```solidity
File: ./contracts/router/GTERouter.sol

275:         for (uint256 i = 0; i < hops.length; i++) {

```

### <a name="GAS-7"></a>[GAS-7] Using `private` rather than `public` for constants, saves gas
If needed, the values can be read from the verified contract source code, or if there are multiple values there can be a single getter function that [returns a tuple](https://github.com/code-423n4/2022-08-frax/blob/90f55a9ce4e25bceed3a74290b854341d8de6afa/src/contracts/FraxlendPair.sol#L156-L178) of the values of all currently-public constants. Saves **3406-3606 gas** in deployment gas due to the compiler not having to create non-payable getter functions for deployment calldata, not having to store the bytes of the value outside of where it's used, and not adding another entry to the method ID table

*Instances (3)*:
```solidity
File: ./contracts/clob/CLOB.sol

127:     uint256 public constant ABI_VERSION = 1;

```

```solidity
File: ./contracts/clob/CLOBManager.sol

100:     uint256 public constant ABI_VERSION = 1;

```

```solidity
File: ./contracts/router/GTERouter.sol

70:     uint256 public constant ABI_VERSION = 1;

```

### <a name="GAS-8"></a>[GAS-8] Increments/decrements can be unchecked in for-loops
In Solidity 0.8+, there's a default overflow check on unsigned integers. It's possible to uncheck this in for-loops and save some gas at each iteration, but at the cost of some code readability, as this uncheck cannot be made inline.

[ethereum/solidity#10695](https://github.com/ethereum/solidity/issues/10695)

The change would be:

```diff
- for (uint256 i; i < numIterations; i++) {
+ for (uint256 i; i < numIterations;) {
 // ...  
+   unchecked { ++i; }
}  
```

These save around **25 gas saved** per instance.

The same can be applied with decrements (which should use `break` when `i == 0`).

The risk of overflow is non-existent for `uint256`.

*Instances (10)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

221:         for (uint256 i = 0; i < accounts.length; i++) {

263:         for (uint256 i; i < params.makerCredits.length; ++i) {

```

```solidity
File: ./contracts/clob/CLOB.sol

908:         for (uint256 i = 0; i < numOrders; i++) {

```

```solidity
File: ./contracts/clob/CLOBManager.sol

230:         for (uint256 i = 0; i < clobs.length; i++) {

243:         for (uint256 i = 0; i < clobs.length; i++) {

256:         for (uint256 i = 0; i < clobs.length; i++) {

279:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: ./contracts/clob/types/FeeData.sol

29:         for (uint256 i; i < fees.length; i++) {

```

```solidity
File: ./contracts/clob/types/TransientMakerData.sol

87:         for (uint256 i; i < length; i++) {

```

```solidity
File: ./contracts/router/GTERouter.sol

275:         for (uint256 i = 0; i < hops.length; i++) {

```

### <a name="GAS-9"></a>[GAS-9] Use != 0 instead of > 0 for unsigned integer comparison

*Instances (17)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

204:         if (fee > 0) {

254:         if (takerFee > 0) {

267:             if (params.side == Side.BUY && credit.quoteAmount > 0) {

271:             } else if (params.side == Side.SELL && credit.baseAmount > 0) {

278:             if (credit.baseAmount > 0) {

282:             if (credit.quoteAmount > 0) {

288:         if (totalBaseMakerFee > 0) {

291:         if (totalQuoteMakerFee > 0) {

```

```solidity
File: ./contracts/clob/CLOB.sol

420:         if (totalBaseTokenRefunded > 0) accountManager.creditAccount(account, baseToken, totalBaseTokenRefunded);

421:         if (totalQuoteTokenRefunded > 0) accountManager.creditAccount(account, quoteToken, totalQuoteTokenRefunded);

440:         if (args.fillOrderType == FillOrderType.FILL_OR_KILL && newOrder.amount > 0) revert FOKOrderNotFilled();

469:         if (args.fillOrderType == FillOrderType.FILL_OR_KILL && newOrder.amount > 0) revert FOKOrderNotFilled();

745:         while (bestAskPrice <= incomingOrder.price && incomingOrder.amount > 0) {

779:         while (bestBidPrice >= incomingOrder.price && incomingOrder.amount > 0) {

966:         if (quoteTokenDelta > 0) {

972:         if (baseTokenDelta > 0) {

```

```solidity
File: ./contracts/clob/types/Book.sol

98:         if (price % tickSize > 0 || price == 0) revert LimitPriceInvalid();

```

### <a name="GAS-10"></a>[GAS-10] WETH address definition can be use directly
WETH is a wrap Ether contract with a specific address in the Ethereum network, giving the option to define it may cause false recognition, it is healthier to define it directly.

    Advantages of defining a specific contract directly:
    
    It saves gas,
    Prevents incorrect argument definition,
    Prevents execution on a different chain and re-signature issues,
    WETH Address : 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2

*Instances (1)*:
```solidity
File: ./contracts/router/GTERouter.sol

72:     WETH public immutable weth;

```


## Non Critical Issues


| |Issue|Instances|
|-|:-|:-:|
| [NC-1](#NC-1) | Replace `abi.encodeWithSignature` and `abi.encodeWithSelector` with `abi.encodeCall` which keeps the code typo/type safe | 1 |
| [NC-2](#NC-2) | Use `string.concat()` or `bytes.concat()` instead of `abi.encodePacked` | 3 |
| [NC-3](#NC-3) | `constant`s should be defined rather than using magic numbers | 5 |
| [NC-4](#NC-4) | Control structures do not follow the Solidity Style Guide | 90 |
| [NC-5](#NC-5) | Default Visibility for constants | 28 |
| [NC-6](#NC-6) | Consider disabling `renounceOwnership()` | 3 |
| [NC-7](#NC-7) | Functions should not be longer than 50 lines | 240 |
| [NC-8](#NC-8) | Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor | 8 |
| [NC-9](#NC-9) | Consider using named mappings | 1 |
| [NC-10](#NC-10) | Numeric values having to do with time should use time units for readability | 1 |
| [NC-11](#NC-11) | Take advantage of Custom Error's return value property | 60 |
| [NC-12](#NC-12) | Avoid the use of sensitive terms | 3 |
| [NC-13](#NC-13) | Variables need not be initialized to zero | 14 |
### <a name="NC-1"></a>[NC-1] Replace `abi.encodeWithSignature` and `abi.encodeWithSelector` with `abi.encodeCall` which keeps the code typo/type safe
When using `abi.encodeWithSignature`, it is possible to include a typo for the correct function signature.
When using `abi.encodeWithSignature` or `abi.encodeWithSelector`, it is also possible to provide parameters that are not of the correct type for the function.

To avoid these pitfalls, it would be best to use [`abi.encodeCall`](https://solidity-by-example.org/abi-encode/) instead.

*Instances (1)*:
```solidity
File: ./contracts/clob/CLOBManager.sol

192:         bytes memory initData = abi.encodeWithSelector(

```

### <a name="NC-2"></a>[NC-2] Use `string.concat()` or `bytes.concat()` instead of `abi.encodePacked`
Solidity version 0.8.4 introduces `bytes.concat()` (vs `abi.encodePacked(<bytes>,<bytes>)`)

Solidity version 0.8.12 introduces `string.concat()` (vs `abi.encodePacked(<str>,<str>), which catches concatenation errors (in the event of a `bytes` data mixed in the concatenation)`)

*Instances (3)*:
```solidity
File: ./contracts/clob/CLOBManager.sol

334:         return keccak256(abi.encodePacked(tokenA, tokenB));

```

```solidity
File: ./contracts/clob/ICLOB.sol

41:         uint96 clientOrderId; // custom order id — id will be uint256(abi.encodePacked(account, clientOrderId))

```

```solidity
File: ./contracts/clob/types/Order.sol

12:         return uint256(bytes32(abi.encodePacked(account, id)));

```

### <a name="NC-3"></a>[NC-3] `constant`s should be defined rather than using magic numbers
Even [assembly](https://github.com/code-423n4/2022-05-opensea-seaport/blob/9d7ce4d08bf3c3010304a0476a785c70c0e90ae7/contracts/lib/TokenTransferrer.sol#L35-L39) can benefit from using readable constants instead of hex/numeric literals

*Instances (5)*:
```solidity
File: ./contracts/clob/CLOBManager.sol

181:         config.quoteSize = 10 ** quoteDecimals;

182:         config.baseSize = 10 ** baseDecimals;

```

```solidity
File: ./contracts/clob/types/FeeData.sol

37:         if (index >= 15) revert FeeTierIndexOutOfBounds();

```

```solidity
File: ./contracts/clob/types/TransientMakerData.sol

60:             let balSlot := add(slot, 2)

139:             let base := add(slot, 2)

```

### <a name="NC-4"></a>[NC-4] Control structures do not follow the Solidity Style Guide
See the [control structures](https://docs.soliditylang.org/en/latest/style-guide.html#control-structures) section of the Solidity Style Guide

*Instances (90)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

78:         if (!_getAccountStorage().isMarket[msg.sender]) revert MarketUnauthorized();

84:         if (msg.sender != gteRouter) revert GTERouterUnauthorized();

90:         if (msg.sender != clobManager) revert CLOBManagerUnauthorized();

218:         if (accounts.length != feeTiers.length) revert UnmatchingArrayLengths();

329:         if (self.accountTokenBalances[account][token] < amount) revert BalanceInsufficient();

```

```solidity
File: ./contracts/clob/CLOB.sol

151:         if (msg.sender != address(factory)) revert ManagerUnauthorized();

351:         if (args.side == Side.BUY) return _processFillBidOrder(ds, account, newOrder, args);

381:         if (newOrder.isExpired()) revert OrderExpired();

385:         if (args.side == Side.BUY) return _processLimitBidOrder(ds, account, newOrder, args);

398:         if (order.id.unwrap() == 0) revert OrderLib.OrderNotFound();

399:         if (order.owner != account) revert AmendUnauthorized();

400:         if (args.limitOrderType != LimitOrderType.POST_ONLY) revert AmendNonPostOnlyInvalid();

420:         if (totalBaseTokenRefunded > 0) accountManager.creditAccount(account, baseToken, totalBaseTokenRefunded);

421:         if (totalQuoteTokenRefunded > 0) accountManager.creditAccount(account, quoteToken, totalQuoteTokenRefunded);

439:         if (totalQuoteSent == 0 || totalBaseReceived == 0) revert ZeroCostTrade();

440:         if (args.fillOrderType == FillOrderType.FILL_OR_KILL && newOrder.amount > 0) revert FOKOrderNotFilled();

468:         if (quoteReceived == 0 || baseSent == 0) revert ZeroCostTrade();

469:         if (args.fillOrderType == FillOrderType.FILL_OR_KILL && newOrder.amount > 0) revert FOKOrderNotFilled();

501:         if (postAmount + quoteTokenAmountSent + baseTokenAmountReceived == 0) revert ZeroOrder();

542:         if (postAmount + quoteTokenAmountReceived + baseTokenAmountSent == 0) revert ZeroOrder();

594:             if (newOrder.price <= minBidPrice) revert MaxOrdersInBookPostNotCompetitive();

627:             if (newOrder.price >= maxAskPrice) revert MaxOrdersInBookPostNotCompetitive();

665:             if (quoteTokenDelta + baseTokenDelta == 0) revert ZeroOrder();

687:         if (order.side == Side.BUY) quoteTokenDelta = ds.getQuoteTokenAmount(order.price, order.amount).toInt256();

761:             if (currMatch.baseDelta == 0) break;

795:             if (currMatch.baseDelta == 0) break;

831:         if (matchData.baseDelta == 0) return matchData;

839:             if (!orderRemoved) ds.metadata().baseTokenOpenInterest -= matchData.baseDelta;

843:             if (!orderRemoved) ds.metadata().quoteTokenOpenInterest -= matchData.quoteDelta;

846:         if (orderRemoved) ds.removeOrderFromBook(makerOrder);

```

```solidity
File: ./contracts/clob/CLOBManager.sol

117:         if (!_getStorage().isCLOB[msg.sender]) revert MarketUnauthorized();

126:         if (_beacon == address(0)) revert InvalidBeaconAddress();

190:         if (self.clob[tokenPairHash] > address(0)) revert MarketExists();

228:         if (clobs.length != maxLimits.length) revert AdminPanelArrayLengthsInvalid();

241:         if (clobs.length != tickSizes.length) revert AdminPanelArrayLengthsInvalid();

254:         if (clobs.length != minLimitOrderAmounts.length) revert AdminPanelArrayLengthsInvalid();

276:         if (accounts.length != toggles.length) revert AdminPanelArrayLengthsInvalid();

290:         if (settings.tickSize.fullMulDiv(settings.minLimitOrderAmountInBase, baseSize) == 0) revert InvalidSettings();

291:         if (settings.minLimitOrderAmountInBase < MIN_MIN_LIMIT_ORDER_AMOUNT_BASE) revert InvalidSettings();

292:         if (settings.maxLimitsPerTx == 0) revert InvalidSettings();

293:         if (settings.tickSize == 0) revert InvalidSettings();

294:         if (settings.lotSizeInBase == 0) revert InvalidSettings();

299:         if (quoteToken == baseToken) revert InvalidPair();

300:         if (quoteToken == address(0)) revert InvalidTokenAddress();

301:         if (baseToken == address(0)) revert InvalidTokenAddress();

```

```solidity
File: ./contracts/clob/ICLOB.sol

39:         uint32 cancelTimestamp; // unix timestamp after which the order is cancelled. Ignore if 0

49:         int256 quoteTokenAmountTraded; // negative if outgoing, positive if incoming

50:         int256 baseTokenAmountTraded; // negative if outgoing, positive if incoming

65:         int256 quoteTokenAmountTraded; // negative if outgoing, positive if incoming

66:         int256 baseTokenAmountTraded; // negative if outgoing, positive if incoming

```

```solidity
File: ./contracts/clob/types/Book.sol

98:         if (price % tickSize > 0 || price == 0) revert LimitPriceInvalid();

103:         if (orderAmountInBase < self.settings().minLimitOrderAmountInBase) revert LimitOrderAmountInvalid();

108:         if (orderAmountInBase % self.settings().lotSizeInBase != 0) revert LotSizeInvalid();

113:         if (self.orders[orderId.toOrderId()].owner > address(0)) revert OrderIdInUse();

175:             if (!allowed) return allowed;

202:                 if (price == 0) break;

221:             if (nextOrder.id.unwrap() == 0) break;

259:             if (limit.numOrders == 0) self.bidTree.insert(order.price);

264:             if (limit.numOrders == 0) self.askTree.insert(order.price);

323:         if (!prev.isNull()) self.orders[prev].nextOrderId = next;

326:         if (!next.isNull()) self.orders[next].prevOrderId = prev;

480:         if (newMaxLimits == 0) revert NewMaxLimitsPerTxInvalid();

488:         if (newTickSize < MIN_LIMIT_PRICE_IN_TICKS) revert NewTickSizeInvalid();

495:         if (newMinLimitOrderAmountInBase < MIN_MIN_LIMIT_ORDER_AMOUNT_BASE) revert NewMinLimitOrderAmountInvalid();

503:         if (newLotSizeInBase == 0) revert NewLotSizeInvalid();

```

```solidity
File: ./contracts/clob/types/FeeData.sol

26:         if (fees.length > U16_PER_WORD) revert FeeTiersExceedsMax();

37:         if (index >= 15) revert FeeTierIndexOutOfBounds();

39:         uint256 shiftBits = index * U16_PER_WORD;

41:         return uint16((PackedFeeRates.unwrap(fees) >> shiftBits) & 0xFFFF);

96:         if (amount == 0) return 0;

108:         if (amount == 0) return 0;

```

```solidity
File: ./contracts/clob/types/Order.sol

105:         if (self.isNull()) revert OrderNotFound();

```

```solidity
File: ./contracts/clob/types/RedBlackTree.sol

27:         if (result == bytes32(0)) return type(uint256).max;

36:         if (result == bytes32(0)) return type(uint256).min;

48:         if (nodeKey == tree.maximum()) return MAX;

49:         if (nodeKey == uint256(type(uint256).max)) revert NodeKeyInvalid();

58:         if (nodeKey == tree.minimum()) return MIN;

59:         if (nodeKey == 0) revert NodeKeyInvalid();

```

```solidity
File: ./contracts/clob/types/TransientMakerData.sol

46:         if (!exists) _addMaker(maker);

73:         if (!exists) _addMaker(maker);

```

```solidity
File: ./contracts/router/GTERouter.sol

89:         if (block.timestamp > deadline) revert DeadlineExceeded();

248:         if (finalAmountOut < amountOutMin) revert SlippageToleranceExceeded();

256:         if (!clobAdminPanel.isMarket(address(clob))) revert InvalidCLOBAddress();

301:         if (market == address(0)) revert CLOBDoesNotExist();

331:         if (path[0] != route.nextTokenIn) revert InvalidTokenRoute();

350:         if (route.nextHopType != HopType.UNI_V2_SWAP) _accountDepositInternal(tokenOut, amountOut);

```

```solidity
File: ./contracts/utils/types/OperatorHelperLib.sol

12:         if (rolesPacked & 1 << uint8(role) == 0 && rolesPacked & 1 == 0) revert OperatorDoesNotHaveRole();

20:         if (msg.sender == account || msg.sender == gteRouter) return;

28:         if (msg.sender == account) return;

41:         if (msg.sender == account || msg.sender == gteRouter) return;

```

### <a name="NC-5"></a>[NC-5] Default Visibility for constants
Some constants are using the default visibility. For readability, consider explicitly declaring them as `internal`.

*Instances (28)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

347:     bytes32 constant ACCOUNT_MANAGER_STORAGE_POSITION =

```

```solidity
File: ./contracts/clob/CLOBManager.sol

35:     bytes32 constant CLOB_MANAGER_STORAGE_POSITION =

```

```solidity
File: ./contracts/clob/types/Book.sol

11: uint256 constant MIN_LIMIT_PRICE_IN_TICKS = 1;

12: uint256 constant MIN_MIN_LIMIT_ORDER_AMOUNT_BASE = 100;

85:     bytes32 constant TRANSIENT_MAX_LIMIT_ALLOWLIST =

89:     bytes32 constant TRANSIENT_LIMITS_PLACED =

359:     bytes32 constant CLOB_STORAGE_POSITION =

362:     bytes32 constant MARKET_CONFIG_STORAGE_POSITION =

365:     bytes32 constant MARKET_SETTINGS_STORAGE_POSITION =

368:     bytes32 constant MARKET_METADATA_STORAGE_POSITION =

```

```solidity
File: ./contracts/clob/types/FeeData.sol

61:     bytes32 constant FEE_DATA_STORAGE_POSITION =

88:     uint256 constant FEE_SCALING = 10_000_000;

```

```solidity
File: ./contracts/clob/types/Order.sol

28: uint256 constant NULL_ORDER_ID = 0;

29: uint32 constant NULL_TIMESTAMP = 0;

```

```solidity
File: ./contracts/clob/types/RedBlackTree.sol

6: uint256 constant MIN = 0;

7: uint256 constant MAX = type(uint256).max;

```

```solidity
File: ./contracts/clob/types/Roles.sol

15:     uint256 constant ADMIN_ROLE = 1 << 0; // _ROLE_0

16:     uint256 constant MARKET_CREATOR = 1 << 1; // _ROLE_1

19:     uint256 constant FEE_COLLECTOR = 1 << 2; // _ROLE_2

20:     uint256 constant FEE_TIER_SETTER = 1 << 3; // _ROLE_3

21:     uint256 constant MAX_LIMITS_EXEMPT_SETTER = 1 << 4; // _ROLE_4

24:     uint256 constant TICK_SIZE_SETTER = 1 << 5; // _ROLE_5

25:     uint256 constant MAX_LIMITS_PER_TX_SETTER = 1 << 6; // _ROLE_6

26:     uint256 constant MIN_LIMIT_ORDER_AMOUNT_SETTER = 1 << 7; // _ROLE_7

```

```solidity
File: ./contracts/clob/types/TransientMakerData.sol

14:     bytes32 constant TRANSIENT_MAKERS_POSITION =

16:     bytes32 constant TRANSIENT_CREDITS_POSITION =

```

```solidity
File: ./contracts/utils/Operator.sol

23:     bytes32 constant OPERATOR_STORAGE_POSITION =

```

```solidity
File: ./contracts/utils/types/EventNonce.sol

15:     bytes32 constant EVENT_NONCE_STORAGE_POSITION =

```

### <a name="NC-6"></a>[NC-6] Consider disabling `renounceOwnership()`
If the plan for your project does not include eventually giving up all ownership control, consider overwriting OpenZeppelin's `Ownable`'s `renounceOwnership()` function in order to disable it.

*Instances (3)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

27: contract AccountManager is IAccountManager, Operator, Initializable, OwnableRoles {

```

```solidity
File: ./contracts/clob/CLOB.sol

28: contract CLOB is ICLOB, Ownable2StepUpgradeable {

```

```solidity
File: ./contracts/clob/CLOBManager.sol

54: contract CLOBManager is ICLOBManager, CLOBAdminOwnableRoles, Initializable {

```

### <a name="NC-7"></a>[NC-7] Functions should not be longer than 50 lines
Overly complex code can make understanding functionality more difficult, try to further modularize your code to ensure readability 

*Instances (240)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

118:     function initialize(address _owner) external initializer {

127:     function getAccountBalance(address account, address token) external view returns (uint256) {

132:     function getEventNonce() external view returns (uint256) {

137:     function getTotalFees(address token) external view returns (uint256) {

142:     function getUnclaimedFees(address token) external view returns (uint256) {

147:     function getFeeTier(address account) external view returns (FeeTiers) {

152:     function getSpotTakerFeeRateForTier(FeeTiers tier) external view returns (uint256) {

157:     function getSpotMakerFeeRateForTier(FeeTiers tier) external view returns (uint256) {

166:     function deposit(address account, address token, uint256 amount) external virtual onlySenderOrOperator(account, OperatorRoles.SPOT_DEPOSIT) {

172:     function depositFromRouter(address account, address token, uint256 amount) external onlyGTERouter {

178:     function withdraw(address account, address token, uint256 amount) external virtual onlySenderOrOperator(account, OperatorRoles.SPOT_WITHDRAW) {

184:     function withdrawToRouter(address account, address token, uint256 amount) external onlyGTERouter {

194:     function registerMarket(address market) external onlyCLOBManager {

200:     function collectFees(address token, address feeRecipient) external virtual onlyOwnerOrRoles(Roles.FEE_COLLECTOR) returns (uint256 fee) {

211:     function setSpotAccountFeeTier(address account, FeeTiers feeTier) external virtual onlyCLOBManager {

217:     function setSpotAccountFeeTiers(address[] calldata accounts, FeeTiers[] calldata feeTiers) external virtual onlyCLOBManager {

231:     function settleIncomingOrder(ICLOB.SettleParams calldata params) external virtual onlyMarket returns (uint256 takerFee) {

297:     function creditAccount(address account, address token, uint256 amount) external virtual onlyMarket {

302:     function creditAccountNoEvent(address account, address token, uint256 amount) external virtual onlyMarket {

307:     function debitAccount(address account, address token, uint256 amount) external virtual onlyMarket {

315:     function _creditAccount(AccountManagerStorage storage self, address account, address token, uint256 amount) internal {

322:     function _creditAccountNoEvent(AccountManagerStorage storage self, address account, address token, uint256 amount) internal {

328:     function _debitAccount(AccountManagerStorage storage self, address account, address token, uint256 amount) internal {

338:     function _getAccountStorage() internal pure returns (AccountManagerStorage storage ds) {

352:     function getAccountManagerStorage() internal pure returns (AccountManagerStorage storage self) {

```

```solidity
File: ./contracts/account-manager/IAccountManager.sol

15:     function getAccountBalance(address account, address token) external view returns (uint256);

16:     function getEventNonce() external view returns (uint256);

17:     function getTotalFees(address token) external view returns (uint256);

18:     function getUnclaimedFees(address token) external view returns (uint256);

19:     function getFeeTier(address account) external view returns (FeeTiers);

20:     function getSpotTakerFeeRateForTier(FeeTiers tier) external view returns (uint256);

21:     function getSpotMakerFeeRateForTier(FeeTiers tier) external view returns (uint256);

26:     function deposit(address account, address token, uint256 amount) external;

27:     function withdraw(address account, address token, uint256 amount) external;

28:     function depositFromRouter(address account, address token, uint256 amount) external;

29:     function withdrawToRouter(address account, address token, uint256 amount) external;

35:     function settleIncomingOrder(ICLOB.SettleParams calldata params) external returns (uint256 takerFee);

38:     function collectFees(address token, address feeRecipient) external returns (uint256 fee);

39:     function setSpotAccountFeeTier(address account, FeeTiers feeTier) external;

40:     function setSpotAccountFeeTiers(address[] calldata accounts, FeeTiers[] calldata feeTiers) external;

43:     function creditAccount(address account, address token, uint256 amount) external;

44:     function creditAccountNoEvent(address account, address token, uint256 amount) external;

45:     function debitAccount(address account, address token, uint256 amount) external;

```

```solidity
File: ./contracts/clob/CLOB.sol

170:     function initialize(MarketConfig memory marketConfig, MarketSettings memory marketSettings, address initialOwner)

182:     function getBaseToken() external view returns (address) {

187:     function getQuoteToken() external view returns (address) {

193:     function getBaseTokenAmount(uint256 price, uint256 quoteAmount) external view returns (uint256) {

199:     function getQuoteTokenAmount(uint256 price, uint256 baseAmount) external view returns (uint256) {

204:     function getMarketConfig() external view returns (MarketConfig memory) {

209:     function getMarketSettings() external view returns (MarketSettings memory) {

214:     function getTickSize() external view returns (uint256) {

219:     function getLotSizeInBase() external view returns (uint256) {

224:     function getOpenInterest() external view returns (uint256 quoteOi, uint256 baseOi) {

229:     function getOrder(uint256 orderId) external view returns (Order memory) {

234:     function getTOB() external view returns (uint256 maxBid, uint256 minAsk) {

239:     function getLimit(uint256 price, Side side) external view returns (Limit memory) {

244:     function getNumBids() external view returns (uint256) {

249:     function getNumAsks() external view returns (uint256) {

254:     function getNextOrders(uint256 startOrderId, uint256 numOrders) external view returns (Order[] memory) {

259:     function getNextBiggestPrice(uint256 price, Side side) external view returns (uint256) {

264:     function getNextSmallestPrice(uint256 price, Side side) external view returns (uint256) {

270:     function getNextOrderId() external view returns (uint256) {

275:     function getEventNonce() external view returns (uint256) {

280:     function getOrdersPaginated(uint256 startPrice, Side side, uint256 pageSize)

295:     function getOrdersPaginated(OrderId startOrderId, uint256 pageSize)

311:     function setMaxLimitsPerTx(uint8 newMaxLimits) external onlyManager {

317:     function setTickSize(uint256 tickSize) external onlyManager {

323:     function setMinLimitOrderAmountInBase(uint256 newMinLimitOrderAmountInBase) external onlyManager {

329:     function setLotSizeInBase(uint256 newLotSizeInBase) external onlyManager {

339:     function postFillOrder(address account, PostFillOrderArgs calldata args)

356:     function postLimitOrder(address account, PostLimitOrderArgs calldata args)

390:     function amend(address account, AmendArgs calldata args)

410:     function cancel(address account, CancelArgs memory args)

574:     function _executeBidLimitOrder(Book storage ds, Order memory newOrder, LimitOrderType limitOrderType)

607:     function _executeAskLimitOrder(Book storage ds, Order memory newOrder, LimitOrderType limitOrderType)

644:     function _processAmend(Book storage ds, Order storage order, AmendArgs calldata args)

674:     function _executeAmendNewOrder(Book storage ds, Order storage order, AmendArgs calldata args)

705:     function _executeAmendAmount(Book storage ds, Order storage order, uint256 amount)

739:     function _matchIncomingBid(Book storage ds, Order memory incomingOrder, bool amountIsBase)

773:     function _matchIncomingAsk(Book storage ds, Order memory incomingOrder, bool amountIsBase)

855:     function _removeExpiredAsk(Book storage ds, Order storage order) internal {

865:     function _removeExpiredBid(Book storage ds, Order storage order) internal {

875:     function _removeNonCompetitiveOrder(Book storage ds, Order storage order) internal {

903:     function _executeCancel(Book storage ds, address account, CancelArgs memory args)

965:     function _settleAmend(Book storage ds, address maker, int256 quoteTokenDelta, int256 baseTokenDelta) internal {

981:     function __CLOB_init(MarketConfig memory marketConfig, MarketSettings memory marketSettings, address initialOwner)

989:     function _getStorage() internal pure returns (Book storage) {

```

```solidity
File: ./contracts/clob/CLOBManager.sol

40:     function getCLOBManagerStorage() internal pure returns (CLOBManagerStorage storage self) {

133:     function initialize(address _owner) external initializer {

142:     function getMarketAddress(address tokenA, address tokenB) external view returns (address marketAddress) {

147:     function isMarket(address market) external view returns (bool) {

152:     function getMaxLimitExempt(address account) external view returns (bool) {

157:     function getEventNonce() external view returns (uint256) {

166:     function createMarket(address baseToken, address quoteToken, SettingsParams calldata settings)

223:     function setMaxLimitsPerTx(ICLOB[] calldata clobs, uint8[] calldata maxLimits)

236:     function setTickSizes(ICLOB[] calldata clobs, uint256[] calldata tickSizes)

249:     function setMinLimitOrderAmounts(ICLOB[] calldata clobs, uint256[] calldata minLimitOrderAmounts)

262:     function setAccountFeeTiers(address[] calldata accounts, FeeTiers[] calldata feeTiers)

271:     function setMaxLimitsExempt(address[] calldata accounts, bool[] calldata toggles)

289:     function _assertValidSettings(SettingsParams calldata settings, uint256 baseSize) internal pure {

298:     function _assertValidTokenPair(address quoteToken, address baseToken) internal pure {

331:     function _getTokenHash(address tokenA, address tokenB) internal pure returns (bytes32) {

338:     function _getStorage() internal pure returns (CLOBManagerStorage storage ds) {

```

```solidity
File: ./contracts/clob/ICLOB.sol

84:     function postLimitOrder(address account, PostLimitOrderArgs memory args)

88:     function postFillOrder(address account, PostFillOrderArgs memory args)

92:     function amend(address account, AmendArgs memory args) external returns (int256 quoteDelta, int256 baseDelta);

94:     function cancel(address account, CancelArgs memory args) external returns (uint256, uint256); // quoteToken refunded, baseToken refunded

97:     function getQuoteTokenAmount(uint256 price, uint256 amountInBaseLots) external view returns (uint256);

99:     function getBaseTokenAmount(uint256 price, uint256 amountInBaseLots) external view returns (uint256);

103:     function gteRouter() external view returns (address);

105:     function getQuoteToken() external view returns (address);

107:     function getBaseToken() external view returns (address);

109:     function getMarketConfig() external view returns (MarketConfig memory);

111:     function getTickSize() external view returns (uint256);

113:     function getOpenInterest() external view returns (uint256, uint256);

115:     function getOrder(uint256 orderId) external view returns (Order memory);

117:     function getTOB() external view returns (uint256, uint256);

119:     function getLimit(uint256 price, Side side) external view returns (Limit memory);

121:     function getNumBids() external view returns (uint256);

123:     function getNumAsks() external view returns (uint256);

125:     function getNextBiggestPrice(uint256 price, Side side) external view returns (uint256);

127:     function getNextSmallestPrice(uint256 price, Side side) external view returns (uint256);

129:     function getNextOrders(uint256 startOrderId, uint256 numOrders) external view returns (Order[] memory);

131:     function getNextOrderId() external view returns (uint256);

133:     function factory() external view returns (ICLOBManager);

135:     function getOrdersPaginated(uint256 startPrice, Side side, uint256 pageSize)

140:     function getOrdersPaginated(OrderId startOrderId, uint256 pageSize)

145:     function setMaxLimitsPerTx(uint8 newMaxLimits) external;

146:     function setTickSize(uint256 newTickSize) external;

147:     function setMinLimitOrderAmountInBase(uint256 newMinLimitOrderAmountInBase) external;

```

```solidity
File: ./contracts/clob/ICLOBManager.sol

27:     function beacon() external view returns (address);

28:     function getMarketAddress(address quoteToken, address baseToken) external view returns (address);

29:     function isMarket(address market) external view returns (bool);

32:     function createMarket(address baseToken, address quoteToken, SettingsParams calldata settings)

36:     function setMaxLimitsPerTx(ICLOB[] calldata clobs, uint8[] calldata maxLimits) external;

37:     function setTickSizes(ICLOB[] calldata clobs, uint256[] calldata tickSizes) external;

38:     function setMinLimitOrderAmounts(ICLOB[] calldata clobs, uint256[] calldata minLimitOrderAmounts) external;

41:     function getMaxLimitExempt(address account) external view returns (bool);

44:     function setAccountFeeTiers(address[] calldata accounts, FeeTiers[] calldata feeTiers) external;

45:     function setMaxLimitsExempt(address[] calldata accounts, bool[] calldata toggles) external;

```

```solidity
File: ./contracts/clob/ILimitLens.sol

9:     function getLimitsFromTOB(address clob, uint256 numLimits, Side side)

14:     function getLimits(address clob, uint256 priceInTicks, uint256 numLimits, Side side)

19:     function getOrdersAtLimits(address clob, uint256[] memory priceInTicks, uint256 numOrdersPerLimit, Side side)

```

```solidity
File: ./contracts/clob/types/Book.sol

95:     function assertLimitPriceInBounds(Book storage self, uint256 price) internal view {

102:     function assertLimitOrderAmountInBounds(Book storage self, uint256 orderAmountInBase) internal view {

107:     function assertLotSizeCompliant(Book storage self, uint256 orderAmountInBase) internal view {

112:     function assertUnusedOrderId(Book storage self, uint256 orderId) internal view {

119:     function setMaxLimitExemptTransient(address who, bool toggle) internal {

129:     function incrementLimitsPlaced(Book storage self, address factory, address account) internal {

145:     function incrementOrderId(Book storage self) internal returns (uint256) {

150:     function addOrderToBook(Book storage self, Order memory order) internal {

157:     function removeOrderFromBook(Book storage self, Order storage order) internal {

165:     function isMaxLimitExempt(Book storage self, address factory, address who) internal returns (bool allowed) {

182:     function getNextOrders(Book storage self, OrderId startOrderId, uint256 numOrders)

211:     function getOrdersPaginated(Book storage ds, Order memory startOrder, uint256 pageSize)

244:     function getTransientLimitsPlaced() internal view returns (uint8 limitsPlaced) {

256:     function _updateBookPostOrder(Book storage self, Order memory order) private returns (Limit storage limit) {

272:     function _updateLimitPostOrder(Book storage self, Limit storage limit, Order memory order) private {

288:     function _updateBookRemoveOrder(Book storage self, Order storage order) private {

302:     function _updateLimitRemoveOrder(Book storage self, Order storage order) private {

374:     function settings(Book storage) internal pure returns (MarketSettings storage) {

378:     function config(Book storage) internal pure returns (MarketConfig storage) {

382:     function metadata(Book storage) internal pure returns (MarketMetadata storage) {

387:     function _getCLOBStorage() internal pure returns (Book storage self) {

397:     function _getMarketConfigStorage() internal pure returns (MarketConfig storage self) {

407:     function _getMarketSettingsStorage() internal pure returns (MarketSettings storage self) {

417:     function _getMarketMetadataStorage() internal pure returns (MarketMetadata storage self) {

427:     function getBestBidPrice(Book storage self) internal view returns (uint256) {

432:     function getBestAskPrice(Book storage self) internal view returns (uint256) {

437:     function getWorstBidPrice(Book storage self) internal view returns (uint256) {

442:     function getWorstAskPrice(Book storage self) internal view returns (uint256) {

447:     function getLimit(Book storage self, uint256 price, Side side) internal view returns (Limit storage) {

452:     function getNextBiggestPrice(Book storage self, uint256 price, Side side) internal view returns (uint256) {

457:     function getNextSmallestPrice(Book storage self, uint256 price, Side side) internal view returns (uint256) {

462:     function getBaseTokenAmount(Book storage self, uint256 price, uint256 quoteAmount)

471:     function getQuoteTokenAmount(Book storage self, uint256 price, uint256 baseAmount)

479:     function setMaxLimitsPerTx(Book storage self, uint8 newMaxLimits) internal {

487:     function setTickSize(Book storage self, uint256 newTickSize) internal {

494:     function setMinLimitOrderAmountInBase(Book storage self, uint256 newMinLimitOrderAmountInBase) internal {

502:     function setLotSizeInBase(Book storage self, uint256 newLotSizeInBase) internal {

510:     function init(Book storage self, MarketConfig memory marketConfig, MarketSettings memory marketSettings) internal {

```

```solidity
File: ./contracts/clob/types/FeeData.sol

25:     function packFeeRates(uint16[] memory fees) internal pure returns (PackedFeeRates) {

36:     function getFeeAt(PackedFeeRates fees, uint256 index) internal pure returns (uint16) {

66:     function getFeeDataStorage() internal pure returns (FeeData storage self) {

91:     function getTakerFee(FeeData storage self, PackedFeeRates takerRates, address account, uint256 amount)

103:     function getMakerFee(FeeData storage self, PackedFeeRates makerRates, address account, uint256 amount)

115:     function getAccountFeeTier(FeeData storage self, address account) internal view returns (FeeTiers tier) {

120:     function setAccountFeeTier(FeeData storage self, address account, FeeTiers feeTier) internal {

127:     function accrueFee(FeeData storage self, address token, uint256 amount) internal {

135:     function claimFees(FeeData storage self, address token) internal returns (uint256 fees) {

```

```solidity
File: ./contracts/clob/types/Order.sol

11:     function getOrderId(address account, uint96 id) internal pure returns (uint256) {

15:     function toOrderId(uint256 id) internal pure returns (OrderId) {

19:     function unwrap(OrderId id) internal pure returns (uint256) {

23:     function isNull(OrderId id) internal pure returns (bool) {

60:     function toOrder(ICLOB.PostLimitOrderArgs calldata args, uint256 orderId, address owner)

74:     function toOrder(ICLOB.PostFillOrderArgs calldata args, uint256 orderId, address owner)

87:     function isExpired(Order memory self) internal view returns (bool) {

93:     function isExpired(uint256 cancelTimestamp) internal view returns (bool) {

99:     function isNull(Order storage self) internal view returns (bool) {

104:     function assertExists(Order storage self) internal view {

```

```solidity
File: ./contracts/clob/types/RedBlackTree.sol

19:     function size(RedBlackTree storage tree) internal view returns (uint256) {

24:     function minimum(RedBlackTree storage tree) internal view returns (uint256) {

33:     function maximum(RedBlackTree storage tree) internal view returns (uint256) {

41:     function contains(RedBlackTree storage tree, uint256 nodeKey) internal view returns (bool) {

47:     function getNextBiggest(RedBlackTree storage tree, uint256 nodeKey) internal view returns (uint256) {

57:     function getNextSmallest(RedBlackTree storage tree, uint256 nodeKey) internal view returns (uint256) {

65:     function insert(RedBlackTree storage tree, uint256 nodeKey) internal {

69:     function remove(RedBlackTree storage tree, uint256 nodeKey) internal {

```

```solidity
File: ./contracts/clob/types/TransientMakerData.sol

23:     function addQuoteToken(address maker, uint256 quoteAmount) internal {

50:     function addBaseToken(address maker, uint256 baseAmount) internal {

77:     function getMakerCreditsAndClearStorage() internal returns (MakerCredit[] memory makerCredits) {

109:     function _getMakersAndClear() internal returns (address[] memory makers) {

134:     function _getBalancesAndClear(address maker) internal returns (uint256 quoteAmount, uint256 baseAmount) {

```

```solidity
File: ./contracts/router/GTERouter.sol

123:     function spotDeposit(address token, uint256 amount, bool fromRouter) external {

154:     function spotWithdraw(address token, uint256 amount) external {

159:     function clobCancel(ICLOB clob, ICLOB.CancelArgs calldata args)

168:     function clobAmend(ICLOB clob, ICLOB.AmendArgs calldata args)

177:     function clobPostLimitOrder(ICLOB clob, ICLOB.PostLimitOrderArgs calldata args)

186:     function clobPostFillOrder(ICLOB clob, ICLOB.PostFillOrderArgs calldata args)

195:     function launchpadSell(address launchToken, uint256 amountInBase, uint256 worstAmountOutQuote)

210:     function launchpadBuy(address launchToken, uint256 amountOutBase, address quoteToken, uint256 worstAmountInQuote)

255:     function _assertValidCLOB(address clob) internal view {

264:     function _executeAllHops(address tokenIn, uint256 amountIn, bytes[] calldata hops)

293:     function _executeClobPostFillOrder(__RouteMetadata__ memory route, bytes calldata hop)

324:     function _executeUniV2SwapExactTokensForTokens(__RouteMetadata__ memory route, bytes calldata hop)

360:     function _accountDepositInternal(address token, uint256 amount) internal {

369:     function getHopType(bytes calldata hop) internal pure returns (GTERouter.HopType) {

```

```solidity
File: ./contracts/utils/Operator.sol

28:     function getOperatorStorage() internal pure returns (OperatorStorage storage self) {

51:     function _getOperatorStorage() internal pure returns (OperatorStorage storage self) {

55:     function getOperatorRoleApprovals(address account, address operator) external view returns (uint256) {

59:     function approveOperator(address operator, uint256 roles) external {

68:     function disapproveOperator(address operator, uint256 roles) external {

```

```solidity
File: ./contracts/utils/interfaces/IOperator.sol

5:     function getOperatorRoleApprovals(address account, address operator) external view returns (uint256);

6:     function approveOperator(address operator, uint256 roles) external;

7:     function disapproveOperator(address operator, uint256 roles) external;

```

```solidity
File: ./contracts/utils/types/EventNonce.sol

19:     function getEventNonceStorage() internal pure returns (EventNonceStorage storage ds) {

37:     function getCurrentNonce() internal view returns (uint256) {

```

```solidity
File: ./contracts/utils/types/OperatorHelperLib.sol

11:     function assertHasRole(uint256 rolesPacked, OperatorRoles role) internal pure {

16:     function onlySenderOrOperator(IOperator operator, address gteRouter, address account, OperatorRoles requiredRole)

27:     function onlySenderOrOperator(IOperator operator, address account, OperatorRoles requiredRole) internal view {

```

### <a name="NC-8"></a>[NC-8] Use a `modifier` instead of a `require/if` statement for a special `msg.sender` actor
If a function is supposed to be access-controlled, a `modifier` should be used instead of a `require/if` statement for more readability.

*Instances (8)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

78:         if (!_getAccountStorage().isMarket[msg.sender]) revert MarketUnauthorized();

84:         if (msg.sender != gteRouter) revert GTERouterUnauthorized();

90:         if (msg.sender != clobManager) revert CLOBManagerUnauthorized();

```

```solidity
File: ./contracts/clob/CLOB.sol

151:         if (msg.sender != address(factory)) revert ManagerUnauthorized();

```

```solidity
File: ./contracts/clob/CLOBManager.sol

117:         if (!_getStorage().isCLOB[msg.sender]) revert MarketUnauthorized();

```

```solidity
File: ./contracts/utils/types/OperatorHelperLib.sol

20:         if (msg.sender == account || msg.sender == gteRouter) return;

28:         if (msg.sender == account) return;

41:         if (msg.sender == account || msg.sender == gteRouter) return;

```

### <a name="NC-9"></a>[NC-9] Consider using named mappings
Consider moving to solidity version 0.8.18 or later, and using [named mappings](https://ethereum.stackexchange.com/questions/51629/how-to-name-the-arguments-in-mapping/145555#145555) to make it easier to understand the purpose of each mapping

*Instances (1)*:
```solidity
File: ./contracts/clob/types/Book.sol

23:     mapping(OrderId => Order) orders;

```

### <a name="NC-10"></a>[NC-10] Numeric values having to do with time should use time units for readability
There are [units](https://docs.soliditylang.org/en/latest/units-and-global-variables.html#time-units) for seconds, minutes, hours, days, and weeks, and since they're defined, they should be used

*Instances (1)*:
```solidity
File: ./contracts/clob/types/Order.sol

29: uint32 constant NULL_TIMESTAMP = 0;

```

### <a name="NC-11"></a>[NC-11] Take advantage of Custom Error's return value property
An important feature of Custom Error is that values such as address, tokenID, msg.value can be written inside the () sign, this kind of approach provides a serious advantage in debugging and examining the revert details of dapps such as tenderly.

*Instances (60)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

78:         if (!_getAccountStorage().isMarket[msg.sender]) revert MarketUnauthorized();

84:         if (msg.sender != gteRouter) revert GTERouterUnauthorized();

90:         if (msg.sender != clobManager) revert CLOBManagerUnauthorized();

218:         if (accounts.length != feeTiers.length) revert UnmatchingArrayLengths();

329:         if (self.accountTokenBalances[account][token] < amount) revert BalanceInsufficient();

```

```solidity
File: ./contracts/clob/CLOB.sol

151:         if (msg.sender != address(factory)) revert ManagerUnauthorized();

381:         if (newOrder.isExpired()) revert OrderExpired();

398:         if (order.id.unwrap() == 0) revert OrderLib.OrderNotFound();

399:         if (order.owner != account) revert AmendUnauthorized();

400:         if (args.limitOrderType != LimitOrderType.POST_ONLY) revert AmendNonPostOnlyInvalid();

439:         if (totalQuoteSent == 0 || totalBaseReceived == 0) revert ZeroCostTrade();

440:         if (args.fillOrderType == FillOrderType.FILL_OR_KILL && newOrder.amount > 0) revert FOKOrderNotFilled();

468:         if (quoteReceived == 0 || baseSent == 0) revert ZeroCostTrade();

469:         if (args.fillOrderType == FillOrderType.FILL_OR_KILL && newOrder.amount > 0) revert FOKOrderNotFilled();

501:         if (postAmount + quoteTokenAmountSent + baseTokenAmountReceived == 0) revert ZeroOrder();

504:             revert ZeroCostTrade();

542:         if (postAmount + quoteTokenAmountReceived + baseTokenAmountSent == 0) revert ZeroOrder();

545:             revert ZeroCostTrade();

579:             revert PostOnlyOrderWouldFill();

594:             if (newOrder.price <= minBidPrice) revert MaxOrdersInBookPostNotCompetitive();

612:             revert PostOnlyOrderWouldFill();

627:             if (newOrder.price >= maxAskPrice) revert MaxOrdersInBookPostNotCompetitive();

652:             revert AmendInvalid();

665:             if (quoteTokenDelta + baseTokenDelta == 0) revert ZeroOrder();

916:                 revert CancelUnauthorized();

```

```solidity
File: ./contracts/clob/CLOBManager.sol

117:         if (!_getStorage().isCLOB[msg.sender]) revert MarketUnauthorized();

126:         if (_beacon == address(0)) revert InvalidBeaconAddress();

190:         if (self.clob[tokenPairHash] > address(0)) revert MarketExists();

228:         if (clobs.length != maxLimits.length) revert AdminPanelArrayLengthsInvalid();

241:         if (clobs.length != tickSizes.length) revert AdminPanelArrayLengthsInvalid();

254:         if (clobs.length != minLimitOrderAmounts.length) revert AdminPanelArrayLengthsInvalid();

276:         if (accounts.length != toggles.length) revert AdminPanelArrayLengthsInvalid();

290:         if (settings.tickSize.fullMulDiv(settings.minLimitOrderAmountInBase, baseSize) == 0) revert InvalidSettings();

291:         if (settings.minLimitOrderAmountInBase < MIN_MIN_LIMIT_ORDER_AMOUNT_BASE) revert InvalidSettings();

292:         if (settings.maxLimitsPerTx == 0) revert InvalidSettings();

293:         if (settings.tickSize == 0) revert InvalidSettings();

294:         if (settings.lotSizeInBase == 0) revert InvalidSettings();

299:         if (quoteToken == baseToken) revert InvalidPair();

300:         if (quoteToken == address(0)) revert InvalidTokenAddress();

301:         if (baseToken == address(0)) revert InvalidTokenAddress();

```

```solidity
File: ./contracts/clob/types/Book.sol

98:         if (price % tickSize > 0 || price == 0) revert LimitPriceInvalid();

103:         if (orderAmountInBase < self.settings().minLimitOrderAmountInBase) revert LimitOrderAmountInvalid();

108:         if (orderAmountInBase % self.settings().lotSizeInBase != 0) revert LotSizeInvalid();

113:         if (self.orders[orderId.toOrderId()].owner > address(0)) revert OrderIdInUse();

133:             revert LimitsPlacedExceedsMax();

480:         if (newMaxLimits == 0) revert NewMaxLimitsPerTxInvalid();

488:         if (newTickSize < MIN_LIMIT_PRICE_IN_TICKS) revert NewTickSizeInvalid();

495:         if (newMinLimitOrderAmountInBase < MIN_MIN_LIMIT_ORDER_AMOUNT_BASE) revert NewMinLimitOrderAmountInvalid();

503:         if (newLotSizeInBase == 0) revert NewLotSizeInvalid();

```

```solidity
File: ./contracts/clob/types/FeeData.sol

26:         if (fees.length > U16_PER_WORD) revert FeeTiersExceedsMax();

37:         if (index >= 15) revert FeeTierIndexOutOfBounds();

```

```solidity
File: ./contracts/clob/types/Order.sol

105:         if (self.isNull()) revert OrderNotFound();

```

```solidity
File: ./contracts/clob/types/RedBlackTree.sol

49:         if (nodeKey == uint256(type(uint256).max)) revert NodeKeyInvalid();

59:         if (nodeKey == 0) revert NodeKeyInvalid();

```

```solidity
File: ./contracts/router/GTERouter.sol

89:         if (block.timestamp > deadline) revert DeadlineExceeded();

248:         if (finalAmountOut < amountOutMin) revert SlippageToleranceExceeded();

256:         if (!clobAdminPanel.isMarket(address(clob))) revert InvalidCLOBAddress();

301:         if (market == address(0)) revert CLOBDoesNotExist();

331:         if (path[0] != route.nextTokenIn) revert InvalidTokenRoute();

```

```solidity
File: ./contracts/utils/types/OperatorHelperLib.sol

12:         if (rolesPacked & 1 << uint8(role) == 0 && rolesPacked & 1 == 0) revert OperatorDoesNotHaveRole();

```

### <a name="NC-12"></a>[NC-12] Avoid the use of sensitive terms
Use [alternative variants](https://www.zdnet.com/article/mysql-drops-master-slave-and-blacklist-whitelist-terminology/), e.g. allowlist/denylist instead of whitelist/blacklist

*Instances (3)*:
```solidity
File: ./contracts/clob/CLOBManager.sol

28:     mapping(address account => bool) maxLimitWhitelist;

153:         return _getStorage().maxLimitWhitelist[account];

280:             self.maxLimitWhitelist[accounts[i]] = toggles[i];

```

### <a name="NC-13"></a>[NC-13] Variables need not be initialized to zero
The default value for variables is zero, so initializing them to zero is superfluous.

*Instances (14)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

221:         for (uint256 i = 0; i < accounts.length; i++) {

259:         uint256 currMakerFee = 0;

260:         uint256 totalQuoteMakerFee = 0;

261:         uint256 totalBaseMakerFee = 0;

```

```solidity
File: ./contracts/clob/CLOB.sol

908:         for (uint256 i = 0; i < numOrders; i++) {

919:             uint256 quoteTokenRefunded = 0;

920:             uint256 baseTokenRefunded = 0;

```

```solidity
File: ./contracts/clob/CLOBManager.sol

230:         for (uint256 i = 0; i < clobs.length; i++) {

243:         for (uint256 i = 0; i < clobs.length; i++) {

256:         for (uint256 i = 0; i < clobs.length; i++) {

279:         for (uint256 i = 0; i < accounts.length; i++) {

```

```solidity
File: ./contracts/clob/types/Book.sol

190:         uint256 count = 0;

```

```solidity
File: ./contracts/clob/types/FeeData.sol

28:         uint256 packedValue = 0;

```

```solidity
File: ./contracts/router/GTERouter.sol

275:         for (uint256 i = 0; i < hops.length; i++) {

```


## Low Issues


| |Issue|Instances|
|-|:-|:-:|
| [L-1](#L-1) | `approve()`/`safeApprove()` may revert if the current approval is not zero | 5 |
| [L-2](#L-2) | Use a 2-step ownership transfer pattern | 2 |
| [L-3](#L-3) | `decimals()` is not a part of the ERC-20 standard | 2 |
| [L-4](#L-4) | Do not use deprecated library functions | 5 |
| [L-5](#L-5) | `safeApprove()` is deprecated | 5 |
| [L-6](#L-6) | Division by zero not prevented | 3 |
| [L-7](#L-7) | Fallback lacking `payable` | 1 |
| [L-8](#L-8) | Initializers could be front-run | 9 |
| [L-9](#L-9) | Signature use at deadlines should be allowed | 2 |
| [L-10](#L-10) | Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership` | 2 |
| [L-11](#L-11) | Unsafe ERC20 operation(s) | 1 |
| [L-12](#L-12) | Upgradeable contract is missing a `__gap[50]` storage variable to allow for new storage variables in later versions | 2 |
| [L-13](#L-13) | Upgradeable contract not initialized | 15 |
### <a name="L-1"></a>[L-1] `approve()`/`safeApprove()` may revert if the current approval is not zero
- Some tokens (like the *very popular* USDT) do not work when changing the allowance from an existing non-zero allowance value (it will revert if the current approval is not zero to protect against front-running changes of approvals). These tokens must first be approved for zero and then the actual allowance can be approved.
- Furthermore, OZ's implementation of safeApprove would throw an error if an approve is attempted from a non-zero value (`"SafeERC20: approve from non-zero to non-zero allowance"`)

Set the allowance to zero immediately before each of the existing allowance calls

*Instances (5)*:
```solidity
File: ./contracts/router/GTERouter.sol

126:             token.safeApprove(address(acctManager), amount);

142:         token.safeApprove(address(acctManager), amount);

149:         address(weth).safeApprove(address(acctManager), msg.value);

337:         path[0].safeApprove(address(uniV2Router), route.prevAmountOut);

361:         token.safeApprove(address(acctManager), amount);

```

### <a name="L-2"></a>[L-2] Use a 2-step ownership transfer pattern
Recommend considering implementing a two step process where the owner or admin nominates an account and the nominated account needs to call an `acceptOwnership()` function for the transfer of ownership to fully succeed. This ensures the nominated EOA account is a valid and active account. Lack of two-step procedure for critical operations leaves them error-prone. Consider adding two step procedure on the critical functions.

*Instances (2)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

27: contract AccountManager is IAccountManager, Operator, Initializable, OwnableRoles {

```

```solidity
File: ./contracts/clob/CLOBManager.sol

54: contract CLOBManager is ICLOBManager, CLOBAdminOwnableRoles, Initializable {

```

### <a name="L-3"></a>[L-3] `decimals()` is not a part of the ERC-20 standard
The `decimals()` function is not a part of the [ERC-20 standard](https://eips.ethereum.org/EIPS/eip-20), and was added later as an [optional extension](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/IERC20Metadata.sol). As such, some valid ERC20 tokens do not support this interface, so it is unsafe to blindly cast all tokens to this interface, and then call this function.

*Instances (2)*:
```solidity
File: ./contracts/clob/CLOBManager.sol

174:         uint8 quoteDecimals = IERC20Metadata(quoteToken).decimals();

175:         uint8 baseDecimals = IERC20Metadata(baseToken).decimals();

```

### <a name="L-4"></a>[L-4] Do not use deprecated library functions

*Instances (5)*:
```solidity
File: ./contracts/router/GTERouter.sol

126:             token.safeApprove(address(acctManager), amount);

142:         token.safeApprove(address(acctManager), amount);

149:         address(weth).safeApprove(address(acctManager), msg.value);

337:         path[0].safeApprove(address(uniV2Router), route.prevAmountOut);

361:         token.safeApprove(address(acctManager), amount);

```

### <a name="L-5"></a>[L-5] `safeApprove()` is deprecated
[Deprecated](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/bfff03c0d2a59bcd8e2ead1da9aed9edf0080d05/contracts/token/ERC20/utils/SafeERC20.sol#L38-L45) in favor of `safeIncreaseAllowance()` and `safeDecreaseAllowance()`. If only setting the initial allowance to the value that means infinite, `safeIncreaseAllowance()` can be used instead. The function may currently work, but if a bug is found in this version of OpenZeppelin, and the version that you're forced to upgrade to no longer has this function, you'll encounter unnecessary delays in porting and testing replacement contracts.

*Instances (5)*:
```solidity
File: ./contracts/router/GTERouter.sol

126:             token.safeApprove(address(acctManager), amount);

142:         token.safeApprove(address(acctManager), amount);

149:         address(weth).safeApprove(address(acctManager), msg.value);

337:         path[0].safeApprove(address(uniV2Router), route.prevAmountOut);

361:         token.safeApprove(address(acctManager), amount);

```

### <a name="L-6"></a>[L-6] Division by zero not prevented
The divisions below take an input parameter which does not have any zero-value checks, which may lead to the functions reverting when zero is passed.

*Instances (3)*:
```solidity
File: ./contracts/clob/CLOB.sol

819:             matchData.baseDelta = (matchedBase.min(takerOrder.amount) / lotSize) * lotSize;

```

```solidity
File: ./contracts/clob/types/Book.sol

467:         return quoteAmount * self.config().baseSize / price;

476:         return baseAmount * price / self.config().baseSize;

```

### <a name="L-7"></a>[L-7] Fallback lacking `payable`

*Instances (1)*:
```solidity
File: ./contracts/router/GTERouter.sol

113:     fallback() external {}

```

### <a name="L-8"></a>[L-8] Initializers could be front-run
Initializers could be front-run, allowing an attacker to either set their own values, take ownership of the contract, and in the best case forcing a re-deployment

*Instances (9)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

118:     function initialize(address _owner) external initializer {

```

```solidity
File: ./contracts/clob/CLOB.sol

170:     function initialize(MarketConfig memory marketConfig, MarketSettings memory marketSettings, address initialOwner)

172:         initializer

174:         __CLOB_init(marketConfig, marketSettings, initialOwner);

981:     function __CLOB_init(MarketConfig memory marketConfig, MarketSettings memory marketSettings, address initialOwner)

984:         __Ownable_init(initialOwner);

985:         CLOBStorageLib.init(_getStorage(), marketConfig, marketSettings);

```

```solidity
File: ./contracts/clob/CLOBManager.sol

133:     function initialize(address _owner) external initializer {

```

```solidity
File: ./contracts/clob/types/Book.sol

510:     function init(Book storage self, MarketConfig memory marketConfig, MarketSettings memory marketSettings) internal {

```

### <a name="L-9"></a>[L-9] Signature use at deadlines should be allowed
According to [EIP-2612](https://github.com/ethereum/EIPs/blob/71dc97318013bf2ac572ab63fab530ac9ef419ca/EIPS/eip-2612.md?plain=1#L58), signatures used on exactly the deadline timestamp are supposed to be allowed. While the signature may or may not be used for the exact EIP-2612 use case (transfer approvals), for consistency's sake, all deadlines should follow this semantic. If the timestamp is an expiration rather than a deadline, consider whether it makes more sense to include the expiration timestamp as a valid timestamp, as is done for deadlines.

*Instances (2)*:
```solidity
File: ./contracts/clob/types/Order.sol

89:         return self.cancelTimestamp != NULL_TIMESTAMP && self.cancelTimestamp < block.timestamp;

95:         return cancelTimestamp != NULL_TIMESTAMP && cancelTimestamp < block.timestamp;

```

### <a name="L-10"></a>[L-10] Use `Ownable2Step.transferOwnership` instead of `Ownable.transferOwnership`
Use [Ownable2Step.transferOwnership](https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol) which is safer. Use it as it is more secure due to 2-stage ownership transfer.

**Recommended Mitigation Steps**

Use <a href="https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable2Step.sol">Ownable2Step.sol</a>
  
  ```solidity
      function acceptOwnership() external {
          address sender = _msgSender();
          require(pendingOwner() == sender, "Ownable2Step: caller is not the new owner");
          _transferOwnership(sender);
      }
```

*Instances (2)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

10: import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";

```

```solidity
File: ./contracts/clob/CLOBManager.sol

21: import {OwnableRoles as CLOBAdminOwnableRoles} from "@solady/auth/OwnableRoles.sol";

```

### <a name="L-11"></a>[L-11] Unsafe ERC20 operation(s)

*Instances (1)*:
```solidity
File: ./contracts/router/GTERouter.sol

141:         permit2.transferFrom(msg.sender, address(this), amount, token);

```

### <a name="L-12"></a>[L-12] Upgradeable contract is missing a `__gap[50]` storage variable to allow for new storage variables in later versions
See [this](https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps) link for a description of this storage variable. While some contracts may not currently be sub-classed, adding the variable now protects against forgetting to add it in the future.

*Instances (2)*:
```solidity
File: ./contracts/clob/CLOB.sol

22: import {Ownable2StepUpgradeable} from "@openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

28: contract CLOB is ICLOB, Ownable2StepUpgradeable {

```

### <a name="L-13"></a>[L-13] Upgradeable contract not initialized
Upgradeable contracts are initialized via an initializer function rather than by a constructor. Leaving such a contract uninitialized may lead to it being taken over by a malicious user

*Instances (15)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

114:         _disableInitializers();

118:     function initialize(address _owner) external initializer {

119:         _initializeOwner(_owner);

```

```solidity
File: ./contracts/clob/CLOB.sol

22: import {Ownable2StepUpgradeable} from "@openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol";

28: contract CLOB is ICLOB, Ownable2StepUpgradeable {

166:         _disableInitializers();

170:     function initialize(MarketConfig memory marketConfig, MarketSettings memory marketSettings, address initialOwner)

172:         initializer

174:         __CLOB_init(marketConfig, marketSettings, initialOwner);

981:     function __CLOB_init(MarketConfig memory marketConfig, MarketSettings memory marketSettings, address initialOwner)

984:         __Ownable_init(initialOwner);

```

```solidity
File: ./contracts/clob/CLOBManager.sol

129:         _disableInitializers();

133:     function initialize(address _owner) external initializer {

134:         _initializeOwner(_owner);

193:             CLOB.initialize.selector,

```


## Medium Issues


| |Issue|Instances|
|-|:-|:-:|
| [M-1](#M-1) | Solady's SafeTransferLib does not check for token contract's existence | 11 |
### <a name="M-1"></a>[M-1] Solady's SafeTransferLib does not check for token contract's existence
There is a subtle difference between the implementation of solady’s SafeTransferLib and OZ’s SafeERC20: OZ’s SafeERC20 checks if the token is a contract or not, solady’s SafeTransferLib does not.
https://github.com/Vectorized/solady/blob/main/src/utils/SafeTransferLib.sol#L10 
`@dev Note that none of the functions in this library check that a token has code at all! That responsibility is delegated to the caller` 


*Instances (11)*:
```solidity
File: ./contracts/account-manager/AccountManager.sol

168:         token.safeTransferFrom(account, address(this), amount);

174:         token.safeTransferFrom(gteRouter, address(this), amount);

180:         token.safeTransfer(account, amount);

186:         token.safeTransfer(gteRouter, amount);

206:             token.safeTransfer(feeRecipient, fee);

```

```solidity
File: ./contracts/router/GTERouter.sol

125:             token.safeTransferFrom(msg.sender, address(this), amount);

126:             token.safeApprove(address(acctManager), amount);

142:         token.safeApprove(address(acctManager), amount);

149:         address(weth).safeApprove(address(acctManager), msg.value);

337:         path[0].safeApprove(address(uniV2Router), route.prevAmountOut);

361:         token.safeApprove(address(acctManager), amount);

```

