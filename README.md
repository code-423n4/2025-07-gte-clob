# GTE Spot CLOB and Router audit details
- Total Prize Pool: $63,250 in USDC
  - HM awards: up to $57,600 in USDC
    - If no valid Highs or Mediums are found, the HM pool is $0
  - QA awards: $2,400 in USDC
  - Judge awards: $3,000 in USDC
  - Scout awards: $250 in USDC
- [Read our guidelines for more details](https://docs.code4rena.com/competitions)
- Starts July 23, 2025 20:00 UTC 
- Ends August 6, 2025 20:00 UTC 

**❗ Important notes for wardens** 
1. A coded, runnable PoC is required for all High/Medium submissions to this audit. 
  - This repo includes a basic template to run the test suite under the `test/c4-poc` folder.
  - PoCs must use the test suite provided in this repo. For more information, **consult the `Creating a PoC` chapter of this document**.
  - Your submission will be marked as Insufficient if the POC is not runnable and working with the provided test suite.
  - Exception: PoC is optional (though recommended) for wardens with signal ≥ 0.68.
2. Judging phase risk adjustments (upgrades/downgrades):
  - High- or Medium-risk submissions downgraded by the judge to Low-risk (QA) will be ineligible for awards.
  - Upgrading a Low-risk finding from a QA report to a Medium- or High-risk finding is not supported.
  - As such, wardens are encouraged to select the appropriate risk level carefully during the submission phase.

## Automated Findings / Publicly Known Issues

The 4naly3er report can be found [here](https://github.com/code-423n4/2025-07-gte-clob/blob/main/4naly3er-report.md).

_Note for C4 wardens: Anything included in this `Automated Findings / Publicly Known Issues` section is considered a publicly known issue and is ineligible for awards._

### CLOB Fill Rounding

On CLOB fill, filled amounts are rounded down to the nearest lot. FOK fill orders *should* not revert if only the amount rounded off is left unfilled, and the user is not charged for the dust. How we state we handle it may have valid issues to target in case any severe loss or otherwise unintended consequence can be demonstrated.

# Overview

## GTE onchain Central-Limit Order Book

The order book is an exchange design that resembles traditional finance. For any given asset pair, an order book maintains a bid and ask side – each one being a list of buy and sell orders, respectively. 

Each order is placed at a different price level, called a limit, and has an order size, which represents the amount of the trade asset that the order wants to buy or sell. Order books use an algorithmic matching engine to match up buy and sell orders, settling the funds of orders that fulfill each other. 

Most order books use “price-time priority” for their matching engines, meaning that the highest buy offers and lowest sell offers are settled first, followed by the chronological sequence of orders placed at that limit price.

GTE leverages its high-performance infrastructure to offer Spot Central Limit Order Books for direct trading of assets with immediate settlement.

## Links

- **Previous audits:** 
  - CLOB: https://github.com/Zellic/publications/blob/master/GTE%20CLOB%20-%20Zellic%20Audit%20Report.pdf
  - CLOB Router: https://github.com/Zellic/publications/blob/master/GTE%20CLOB%20and%20Launchpad-%20Zellic%20Audit%20Report.pdf
- **Documentation:** https://docs.gte.xyz/home/overview/about-gte
- **Website:** https://www.gte.xyz
- **X/Twitter:** https://x.com/GTE_XYZ
- **Code walk-through**: https://youtu.be/9TOnTuSh3Qg
  
---

# Scope

### Files in scope

| Contract | SLOC  | Libraries used |  
| ----------- | ----------- | ----------- |
| [contracts/account-manager/AccountManager.sol](https://github.com/code-423n4/2025-07-gte-clob/blob/main/contracts/account-manager/AccountManager.sol) | 211 | N/A |
| [contracts/clob/CLOB.sol](https://github.com/code-423n4/2025-07-gte-clob/blob/main/contracts/clob/CLOB.sol) | 549 |contracts/utils/interfaces/IOperator.sol<br>contracts/utils/Operator.sol<br>contracts/utils/types/OperatorHelperLib.sol<br>contracts/utils/types/EventNonce.sol<br>@solady/utils/SafeCastLib.sol<br>@solady/utils/FixedPointMathLib.sol<br>@openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol|
| [contracts/clob/CLOBManager.sol](https://github.com/code-423n4/2025-07-gte-clob/blob/main/contracts/clob/CLOBManager.sol) |  179  |contracts/utils/types/EventNonce.sol<br>@solady/utils/Initializable.sol<br>@solady/utils/SafeTransferLib.sol<br>@solady/utils/FixedPointMathLib.sol<br>@solady/auth/OwnableRoles.sol<br>@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol<br>@openzeppelin/proxy/beacon/BeaconProxy.sol|
| [contracts/clob/ICLOB.sol](https://github.com/code-423n4/2025-07-gte-clob/blob/main/contracts/clob/ICLOB.sol) | 70 | |
| [contracts/clob/ICLOBManager.sol](https://github.com/code-423n4/2025-07-gte-clob/blob/main/contracts/clob/ICLOBManager.sol) | 21 | |
| [contracts/clob/ILimitLens.sol](https://github.com/code-423n4/2025-07-gte-clob/blob/main/contracts/clob/ILimitLens.sol) | 6 | |
| [contracts/clob/types/Book.sol](https://github.com/code-423n4/2025-07-gte-clob/blob/main/contracts/clob/types/Book.sol)  | 323  |contracts/utils/types/EventNonce.sol|
| [contracts/clob/types/FeeData.sol](https://github.com/code-423n4/2025-07-gte-clob/blob/main/contracts/clob/types/FeeData.sol)  | 81  |contracts/utils/types/EventNonce.sol<br>@solady/utils/SafeTransferLib.sol<br>@solady/utils/FixedPointMathLib.sol|
| [contracts/clob/types/Order.sol](https://github.com/code-423n4/2025-07-gte-clob/blob/main/contracts/clob/types/Order.sol)  | 66 | |
| [contracts/clob/types/RedBlackTree.sol](https://github.com/code-423n4/2025-07-gte-clob/blob/main/contracts/clob/types/RedBlackTree.sol) | 45 |@solady/utils/RedBlackTreeLib.sol|
| [contracts/clob/types/Roles.sol](https://github.com/code-423n4/2025-07-gte-clob/blob/main/contracts/clob/types/Roles.sol) | 11 | |
| [contracts/clob/types/TransientMakerData.sol](https://github.com/code-423n4/2025-07-gte-clob/blob/main/contracts/clob/types/TransientMakerData.sol) | 102 | |
| [contracts/router/GTERouter.sol](https://github.com/code-423n4/2025-07-gte-clob/blob/main/contracts/router/GTERouter.sol)  | 202  |contracts/clob/types/Order.sol<br>contracts/clob/ICLOBManager.sol<br>contracts/launchpad/interfaces/ILaunchpad.sol<br>contracts/clob/ICLOB.sol<br>@permit2/interfaces/IAllowanceTransfer.sol<br>@solady/tokens/WETH.sol<br>@solady/utils/SafeTransferLib.sol<br>@solady/utils/FixedPointMathLib.sol<br>@solady/utils/ReentrancyGuardTransient.sol|
| [contracts/utils/Operator.sol](https://github.com/code-423n4/2025-07-gte-clob/blob/main/contracts/utils/Operator.sol)  | 51 | |
| [contracts/utils/types/EventNonce.sol](https://github.com/code-423n4/2025-07-gte-clob/blob/main/contracts/utils/types/EventNonce.sol) | 22 | |
| [contracts/utils/types/OperatorHelperLib.sol](https://github.com/code-423n4/2025-07-gte-clob/blob/main/contracts/utils/types/OperatorHelperLib.sol) |  24 | |
| **Totals** |  **1963** | | |


*For a machine-readable version, see [scope.txt](https://github.com/code-423n4/2025-07-gte-clob/blob/main/scope.txt)*

### Files out of scope

| File | 
| ---- | 
| [contracts/launchpad/\*\*.\*\*](https://github.com/code-423n4/2025-07-gte-clob/tree/main/contracts/launchpad) |
| [script/\*\*.\*\*](https://github.com/code-423n4/2025-07-gte-clob/tree/main/script) | 
| [test/\*\*.\*\*](https://github.com/code-423n4/2025-07-gte-clob/tree/main/test) | 

*For a machine-readable version, see [out_of_scope.txt](https://github.com/code-423n4/2025-07-gte-clob/blob/main/out_of_scope.txt)*

# Additional context

## Areas of concern (where to focus for bugs)

### Rounding / Overflows

Any form of rounding / overflow with regards to order filling / order amendment that can result in someone erroneously receiving more tokens than they deserve is unacceptable. Neither party in a trade, taker nor maker, should end up with more tokens than either had available to match.

### Denial-of-Service Attacks

The main type of DOS we are worried about is Order Flooding. Order Flooding is when someone crowds either the top, or a distant price in the book with many orders that would take many transactions to clear, thus slowing down everyone's ability to price the book equally to the broader market. We currently implement a minOrderSize and maxLimitsPlacedPerTx to combat this, but we do not have admin cancel. 

We are mulling the idea of allowing admin cancels so long as the orders being cancelled are under a certain % of the spot oi, or far enough away from top of book, but its not in scope to discuss the viability of this.

We want to make sure that our intended goal of 1) not letting non-whitelisted callers place more limits in a txn than the min setting and 2) enforcing minLimitOrderAmountInBase both cannot be manipulated. Auditors should focus on breaking these assumptions, and we can focus on the viability of our DOS protection as a whole vs adding an admin cancel

## Main invariants

### Token Balance

For a given token (`T`) and all markets (`M`) it is either the base or quote asset of, the balance of the AccountManager.sol (`AM`) must be equal to: 

> (T's feesAccrued in AM) + (account balances of T in AM) + (all open orders in all Ms that are selling T, converted to quote amount if is that M's quote token)

### Access Control

For functions guarded by an operator approval check, only the "account", or a caller who has been approved by the account for that operator role required should be able to call the function

## All trusted roles in the protocol

All described roles are expected to be multi-signature wallets or automated smart contracts with on-chain risk parameters for the foreseeable future.

| Role                                | Description                       |
| --------------------------------------- | ---------------------------- |
| `MARKET_CREATOR`                             | Can create CLOB markets                       |
| `MAX_LIMITS_PER_TX_SETTER` | Can configure maximum limits per transaction of a CLOB |
| `TICK_SIZE_SETTER` | Can configure the tick size of a CLOB |
| `MIN_LIMIT_ORDER_AMOUNT_SETTER` | Can set the minimum limit order amount of a CLOB |
| `FEE_TIER_SETTER` | Can set the spot account fee tiers |
| `MAX_LIMITS_EXEMPT_SETTER` | Can configure the accounts that are exempt from maximum limits |
| Owner (`CLOBManager`)                         | All of the above capabilities                |
| `FEE_COLLECTOR` / Owner (`AccountManager`) | Can collect accrued fees |

## Running tests

The codebase utilizes the `forge` framework for compiling its contracts and executing tests coded in `Solidity`.

### Prerequisites

- `forge` (`1.2.3-stable` tested)

### Setup

Once the above prerequisite has been successfully installed, the following commands can be executed to setup the repository:

```bash!
git clone https://github.com/code-423n4/2025-07-gte-clob
cd 2025-07-gte-clob
```

### Tests

To run tests, the `forge test` command should be executed:

```bash! 
forge test
```

### Coverage

Coverage can be executed via the built-in `coverage` command of `forge` (IR minimum is required):

```bash! 
FOUNDRY_PROFILE=coverage forge coverage --ir-minimum --report lcov
```

| File | Coverage (Line / Function / Branch) |
| ---- | -------- |
| contracts/account-manager/AccountManager.sol | 92.1% / 90.0% / 87.5% |
| contracts/clob/CLOB.sol | 96.2% / 90.6% / 84.5% |
| contracts/clob/CLOBManager.sol | 92.0% / 89.5% / 80.0% |
| contracts/clob/types/Book.sol | 93.7% / 100.0% / 82.8% |
| contracts/clob/types/FeeData.sol | 97.1% / 100.0% / 0.0% |
| contracts/clob/types/Order.sol | 100.0% / 100.0% / 0.0% |
| contracts/clob/types/RedBlackTree.sol | 100.0% / 100.0% / 0.0% |
| contracts/clob/types/TransientMakerData.sol | 36.8% / 100.0% / 33.3% |
| contracts/router/GTERouter.sol | 88.4% / 75.0% / 66.7% |
| contracts/utils/Operator.sol | 94.1% / 100.0% / 100.0% |
| contracts/utils/types/EventNonce.sol | 88.9% / 100.0% / 100.0% |
| contracts/utils/types/OperatorHelperLib.sol | 28.6% / 50.0% / 0.0% |
| **Totals** | **83.9% / 91.2% / 52.9%** |

## Creating a PoC

The project is composed of three core systems; the `CLOB` system, the `AccountManager` contract, and the `GTERouter` contract. Within the codebase, we have introduced a `PoC.t.sol` test file under the `test/c4-poc` folder that sets up each system with mock implementations to allow PoCs to be constructed in a straightforward manner. 

Specifically, we combined the logic of the `RouterTestBase.t.sol` and `CLOBTestBase.sol` files manually to combine the underlying deployments.

Depending on where the vulnerability lies, the PoC should utilize the relevant storage entries (i.e. the `router` in case a router vulnerability is demonstrated etc.).

For a submission to be considered valid, the test case **should execute successfully** via the following command:

```bash 
forge test --match-test submissionValidity
```

## Miscellaneous

Employees of GTE and employees' family members are ineligible to participate in this audit.

Code4rena's rules cannot be overridden by the contents of this README. In case of doubt, please check with C4 staff.
