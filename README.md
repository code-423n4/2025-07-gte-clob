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
## 🐺 C4 staff: delete the PoC requirement section if not applicable - i.e. for non-Solidity/EVM audits.
1. A coded, runnable PoC is required for all High/Medium submissions to this audit. 
  - This repo includes a basic template to run the test suite.
  - PoCs must use the test suite provided in this repo.
  - Your submission will be marked as Insufficient if the POC is not runnable and working with the provided test suite.
  - Exception: PoC is optional (though recommended) for wardens with signal ≥ 0.68.
2. Judging phase risk adjustments (upgrades/downgrades):
  - High- or Medium-risk submissions downgraded by the judge to Low-risk (QA) will be ineligible for awards.
  - Upgrading a Low-risk finding from a QA report to a Medium- or High-risk finding is not supported.
  - As such, wardens are encouraged to select the appropriate risk level carefully during the submission phase.

## Automated Findings / Publicly Known Issues

The 4naly3er report can be found [here](https://github.com/code-423n4/2025-07-gte/blob/main/4naly3er-report.md).

_Note for C4 wardens: Anything included in this `Automated Findings / Publicly Known Issues` section is considered a publicly known issue and is ineligible for awards._

On CLOB fill, filled amounts are rounded down to the nearest lot. FOK fill orders *should* not revert if only the amount rounded off is left unfilled, and the user is not charged for the dust. the known issue being lot dust exists, how we state we handle it may have valid issues to target.

✅ SCOUTS: Please format the response above 👆 so its not a wall of text and its readable.

# Overview

[ ⭐️ SPONSORS: add info here ]

## Links

- **Previous audits:**  (your teammates on zellic may share the previous gte audits here)
  - ✅ SCOUTS: If there are multiple report links, please format them in a list.
- **Documentation:** https://docs.gte.xyz/home/overview/about-gte
- **Website:** https://www.gte.xyz
- **X/Twitter:** https://x.com/GTE_XYZ
  
---

# Scope

[ ✅ SCOUTS: add scoping and technical details here ]

### Files in scope
- ✅ This should be completed using the `metrics.md` file
- ✅ Last row of the table should be Total: SLOC
- ✅ SCOUTS: Have the sponsor review and and confirm in text the details in the section titled "Scoping Q amp; A"

*For sponsors that don't use the scoping tool: list all files in scope in the table below (along with hyperlinks) -- and feel free to add notes to emphasize areas of focus.*

| Contract | SLOC | Purpose | Libraries used |  
| ----------- | ----------- | ----------- | ----------- |
| [contracts/folder/sample.sol](https://github.com/code-423n4/repo-name/blob/contracts/folder/sample.sol) | 123 | This contract does XYZ | [`@openzeppelin/*`](https://openzeppelin.com/contracts/) |

### Files out of scope
✅ SCOUTS: List files/directories out of scope

# Additional context

## Areas of concern (where to focus for bugs)
## Rounding / overflow
Any form of rounding / overflow with regards to order filling / order amendment that can result in someone erroneously receiving more tokens than they deserve is unacceptable. Neither party in a trade, taker nor maker, should end up with more tokens than either had available to match.

## DOS
The main type of DOS we are worried about is Order Flooding. Order Flooding is when someone crowds either the top, or a distant price in the book with many orders that would take many transactions to clear, thus slowing down everyone's ability to price the book equally to the broader market. We currently implement a minOrderSize and maxLimitsPlacedPerTx to combat this, but we do not have admin cancel. 

We are mulling the idea of allowing admin cancels so long as the orders being cancelled are under a certain % of the spot oi, or far enough away from top of book, but its not in scope to discuss the viability of this.

We want to make sure that our intended goal of 1) not letting non-whitelisted callers place more limits in a txn than the min setting and 2) enforcing minLimitOrderAmountInBase both cannot be manipulated. Auditors should focus on breaking these assumptions, and we can focus on the viability of our DOS protection as a whole vs adding an admin cancel

✅ SCOUTS: Please format the response above 👆 so its not a wall of text and its readable.

## Main invariants

1) for a given token (T) and all markets (M) it is either the base / quote assets of, the balance of the AccountManager.sol (AM) must be equal to: 

(T's feesAccrued in AM) + (account balances of T in AM) + (all open orders in all Ms that are selling T, converted to quote amount if is that M's quote token)

2) For functions guarded by an operator approval check, only the "account", or a caller who has been approved by the account for that operator role required should be able to call the function

✅ SCOUTS: Please format the response above 👆 so its not a wall of text and its readable.

## All trusted roles in the protocol

- Ownable / Ownable roles owners
- contracts/clob/types/Roles.sol. these are the roles that have access *in addition* to the owner of the CLOBManager (we may slim these down under a smaller number of roles in the future)
- ERC1967 adminOf(CLOBManager)

all of these will either be a multisig, or contract with on-chain risk parameters for the foreseeable future

✅ SCOUTS: Please format the response above 👆 using the template below👇

| Role                                | Description                       |
| --------------------------------------- | ---------------------------- |
| Owner                          | Has superpowers                |
| Administrator                             | Can change fees                       |

✅ SCOUTS: Please format the response above 👆 so its not a wall of text and its readable.

## Running tests

*These instructions are for the C4 scout to prepare the audit repo off of our private repo*

1) git checkout 
 install foundry (https://github.com/liquid-labs-inc/gte-contracts)
2) run forge test

If forge test fails, it likely means that you do not have access to gte-univ2 contracts repo, please reach out if this happens

✅ SCOUTS: Please format the response above 👆 using the template below👇

```bash
git clone https://github.com/code-423n4/2023-08-arbitrum
git submodule update --init --recursive
cd governance
foundryup
make install
make build
make sc-election-test
```
To run code coverage
```bash
make coverage
```

✅ SCOUTS: Add a screenshot of your terminal showing the test coverage

## Miscellaneous
Employees of GTE and employees' family members are ineligible to participate in this audit.

Code4rena's rules cannot be overridden by the contents of this README. In case of doubt, please check with C4 staff.

# Scope

*See [scope.txt](https://github.com/code-423n4/2025-07-gte-clob/blob/main/scope.txt)*

### Files in scope


| File   | Logic Contracts | Interfaces | nSLOC | Purpose | Libraries used |
| ------ | --------------- | ---------- | ----- | -----   | ------------ |
| /contracts/clob/CLOB.sol | 1| **** | 549 | |contracts/utils/interfaces/IOperator.sol<br>contracts/utils/Operator.sol<br>contracts/utils/types/OperatorHelperLib.sol<br>contracts/utils/types/EventNonce.sol<br>@solady/utils/SafeCastLib.sol<br>@solady/utils/FixedPointMathLib.sol<br>@openzeppelin-contracts-upgradeable/access/Ownable2StepUpgradeable.sol|
| /contracts/clob/CLOBManager.sol | 2| **** | 179 | |contracts/utils/types/EventNonce.sol<br>@solady/utils/Initializable.sol<br>@solady/utils/SafeTransferLib.sol<br>@solady/utils/FixedPointMathLib.sol<br>@solady/auth/OwnableRoles.sol<br>@openzeppelin/token/ERC20/extensions/IERC20Metadata.sol<br>@openzeppelin/proxy/beacon/BeaconProxy.sol|
| /contracts/clob/ICLOB.sol | ****| 1 | 70 | ||
| /contracts/clob/ICLOBManager.sol | ****| 1 | 21 | ||
| /contracts/clob/ILimitLens.sol | ****| 1 | 6 | ||
| /contracts/clob/types/Book.sol | 2| **** | 323 | |contracts/utils/types/EventNonce.sol|
| /contracts/clob/types/FeeData.sol | 3| **** | 81 | |contracts/utils/types/EventNonce.sol<br>@solady/utils/SafeTransferLib.sol<br>@solady/utils/FixedPointMathLib.sol|
| /contracts/clob/types/Order.sol | 2| **** | 66 | ||
| /contracts/clob/types/RedBlackTree.sol | 1| **** | 45 | |@solady/utils/RedBlackTreeLib.sol|
| /contracts/clob/types/Roles.sol | 1| **** | 11 | ||
| /contracts/clob/types/TransientMakerData.sol | 1| **** | 102 | ||
| /contracts/router/GTERouter.sol | 2| **** | 202 | |contracts/clob/types/Order.sol<br>contracts/clob/ICLOBManager.sol<br>contracts/launchpad/interfaces/ILaunchpad.sol<br>contracts/clob/ICLOB.sol<br>@permit2/interfaces/IAllowanceTransfer.sol<br>@solady/tokens/WETH.sol<br>@solady/utils/SafeTransferLib.sol<br>@solady/utils/FixedPointMathLib.sol<br>@solady/utils/ReentrancyGuardTransient.sol|
| /contracts/utils/Operator.sol | 2| **** | 51 | ||
| /contracts/utils/interfaces/IOperator.sol | ****| 1 | 3 | ||
| /contracts/utils/types/EventNonce.sol | 1| **** | 22 | ||
| /contracts/utils/types/OperatorHelperLib.sol | 1| **** | 24 | ||
| **Totals** | **19** | **4** | **1755** | | |

### Files out of scope

*See [out_of_scope.txt](https://github.com/code-423n4/2025-07-gte-clob/blob/main/out_of_scope.txt)*

| File         |
| ------------ |
| ./contracts/account-manager/AccountManager.sol |
| ./contracts/account-manager/IAccountManager.sol |
| ./contracts/launchpad/Distributor.sol |
| ./contracts/launchpad/LaunchToken.sol |
| ./contracts/launchpad/LaunchpadLPVault.sol |
| ./contracts/launchpad/interfaces/IBondingCurveMinimal.sol |
| ./contracts/launchpad/interfaces/IDistributor.sol |
| ./contracts/launchpad/interfaces/IGTELaunchpadV2Pair.sol |
| ./contracts/launchpad/interfaces/ILaunchpad.sol |
| ./contracts/launchpad/interfaces/ISimpleLaunchpad.sol |
| ./contracts/launchpad/interfaces/IUniV2Factory.sol |
| ./contracts/launchpad/interfaces/IUniswapV2FactoryMinimal.sol |
| ./contracts/launchpad/interfaces/IUniswapV2Pair.sol |
| ./contracts/launchpad/interfaces/IUniswapV2RouterMinimal.sol |
| ./contracts/launchpad/libraries/RewardsTracker.sol |
| ./contracts/router/interfaces/IUniswapV2Router01.sol |
| ./script/ScriptProtector.s.sol |
| ./script/helpers/MockUSDC.s.sol |
| ./script/misc/DeployUniV2Pair.s.sol |
| ./script/operator/Operator.s.sol |
| ./script/spot-clob/CLOBManager.s.sol |
| ./script/upgrades/UpgradeCLOB.s.sol |
| ./script/upgrades/UpgradeCLOBManager.s.sol |
| ./test/clob/fuzz/auth/Auth.t.sol |
| ./test/clob/fuzz/clob/CLOBViews.t.sol |
| ./test/clob/fuzz/red-black-tree/RedBlackTree.t.sol |
| ./test/clob/mock/CLOBAnvilFuzzTrader.sol |
| ./test/clob/unit/clob/CLOBAmendIncrease.t.sol |
| ./test/clob/unit/clob/CLOBAmendNewPrice.t.sol |
| ./test/clob/unit/clob/CLOBAmendReduce.t.sol |
| ./test/clob/unit/clob/CLOBAmmendNewSide.t.sol |
| ./test/clob/unit/clob/CLOBCancel.t.sol |
| ./test/clob/unit/clob/CLOBFill.t.sol |
| ./test/clob/unit/clob/CLOBPost.t.sol |
| ./test/clob/unit/clob/CLOBViews.sol |
| ./test/clob/unit/red-black-tree/RedBlackTree.t.sol |
| ./test/clob/unit/types/TransientMakerData.t.sol |
| ./test/clob/utils/CLOBTestBase.sol |
| ./test/harnesses/ERC20Harness.sol |
| ./test/launchpad/Distributor.t.sol |
| ./test/live-tests/DeployUniV2Pair.t.sol |
| ./test/mocks/MockDistributor.sol |
| ./test/mocks/MockLaunchpad.sol |
| ./test/mocks/MockRewardsTracker.sol |
| ./test/mocks/MockTree.sol |
| ./test/mocks/MockUniV2Router.sol |
| ./test/mocks/TransientMakerDataHarness.sol |
| ./test/router/RouterUnit.t.sol |
| ./test/router/utils/RouterTestBase.t.sol |
| ./test/utils/Operator.t.sol |
| Totals: 50 |

