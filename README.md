# ✨ So you want to run an audit

This `README.md` contains a set of checklists for our audit collaboration. This is your audit repo, which is used for scoping your audit and for providing information to wardens

Some of the checklists in this doc are for our scouts and some of them are for **you as the audit sponsor (⭐️)**.

---

# Repo setup

## ⭐️ Sponsor: Add code to this repo

- [ ] Create a PR to this repo with the below changes:
- [ ] Confirm that this repo is a self-contained repository with working commands that will build (at least) all in-scope contracts, and commands that will run tests producing gas reports for the relevant contracts.
- [ ] Please have final versions of contracts and documentation added/updated in this repo **no less than 48 business hours prior to audit start time.**
- [ ] Be prepared for a 🚨code freeze🚨 for the duration of the audit — important because it establishes a level playing field. We want to ensure everyone's looking at the same code, no matter when they look during the audit. (Note: this includes your own repo, since a PR can leak alpha to our wardens!)

## ⭐️ Sponsor: Repo checklist

- [ ] Modify the [Overview](#overview) section of this `README.md` file. Describe how your code is supposed to work with links to any relevant documentation and any other criteria/details that the auditors should keep in mind when reviewing. (Here are two well-constructed examples: [Ajna Protocol](https://github.com/code-423n4/2023-05-ajna) and [Maia DAO Ecosystem](https://github.com/code-423n4/2023-05-maia))
- [ ] Optional: pre-record a high-level overview of your protocol (not just specific smart contract functions). This saves wardens a lot of time wading through documentation.
- [ ] Review and confirm the details created by the Scout (technical reviewer) who was assigned to your contest. *Note: any files not listed as "in scope" will be considered out of scope for the purposes of judging, even if the file will be part of the deployed contracts.*  

---

# Sponsorname audit details
- Total Prize Pool: XXX XXX USDC (Notion: Total award pool)
  - HM awards: up to XXX XXX USDC (Notion: HM (main) pool)
    - If no valid Highs or Mediums are found, the HM pool is $0 
  - QA awards: XXX XXX USDC (Notion: QA pool)
  - Judge awards: XXX XXX USDC (Notion: Judge Fee)
  - Scout awards: $500 USDC (Notion: Scout fee - but usually $500 USDC)
  - (this line can be removed if there is no mitigation) Mitigation Review: XXX XXX USDC
- [Read our guidelines for more details](https://docs.code4rena.com/competitions)
- Starts XXX XXX XX 20:00 UTC (ex. `Starts March 22, 2023 20:00 UTC`)
- Ends XXX XXX XX 20:00 UTC (ex. `Ends March 30, 2023 20:00 UTC`)

**❗ Important notes for wardens** 
## 🐺 C4 staff: delete the PoC requirement section if not applicable - i.e. for non-Solidity/EVM audits.
1. A coded, runnable PoC is required for all High/Medium submissions to this audit. 
  - This repo includes a basic template to run the test suite.
  - PoCs must use the test suite provided in this repo.
  - Your submission will be marked as Insufficient if the POC is not runnable and working with the provided test suite.
  - Exception: PoC is optional (though recommended) for wardens with signal ≥ 0.68.
1. Judging phase risk adjustments (upgrades/downgrades):
  - High- or Medium-risk submissions downgraded by the judge to Low-risk (QA) will be ineligible for awards.
  - Upgrading a Low-risk finding from a QA report to a Medium- or High-risk finding is not supported.
  - As such, wardens are encouraged to select the appropriate risk level carefully during the submission phase.

## Automated Findings / Publicly Known Issues

The 4naly3er report can be found [here](https://github.com/code-423n4/YYYY-MM-contest-candidate/blob/main/4naly3er-report.md).

_Note for C4 wardens: Anything included in this `Automated Findings / Publicly Known Issues` section is considered a publicly known issue and is ineligible for awards._
## 🐺 C4: Begin Gist paste here (and delete this line)





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

