# GTERouter Dependencies from /launchpad and /perps Directories

## Summary

The GTERouter contract has dependencies ONLY from the `/launchpad` directory. There are NO dependencies from the `/perps` directory.

## Direct Dependencies from GTERouter.sol

1. **From /launchpad directory:**
   - `/contracts/launchpad/interfaces/ILaunchpad.sol` (Line 10 of GTERouter.sol)

## Indirect Dependencies (via ILaunchpad.sol)

The ILaunchpad interface imports the following from the launchpad directory:

2. `/contracts/launchpad/LaunchToken.sol`
3. `/contracts/launchpad/BondingCurves/IBondingCurveMinimal.sol`
4. `/contracts/launchpad/interfaces/IDistributor.sol`
5. `/contracts/launchpad/interfaces/IUniswapV2RouterMinimal.sol`
6. `/contracts/launchpad/interfaces/IUniswapV2FactoryMinimal.sol`
7. `/contracts/launchpad/LaunchpadLPVault.sol`

## Additional Dependencies (from imported interfaces)

8. `/contracts/launchpad/uniswap/interfaces/IGTELaunchpadV2Pair.sol` (imported by IDistributor.sol)
9. `/contracts/launchpad/libraries/RewardsTracker.sol` (imported by IDistributor.sol)

## Implementation Dependencies (used in tests/deployment)

10. `/contracts/launchpad/SimpleLaunchpad.sol` (implementation of ILaunchpad)
11. `/contracts/launchpad/BondingCurves/SimpleBondingCurve.sol` (implementation of IBondingCurveMinimal)
12. `/contracts/launchpad/interfaces/ISimpleLaunchpad.sol` (imported by LaunchToken.sol)

## Complete List of Required Files from /launchpad

```
contracts/launchpad/
├── BondingCurves/
│   ├── IBondingCurveMinimal.sol
│   └── SimpleBondingCurve.sol
├── interfaces/
│   ├── IDistributor.sol
│   ├── ILaunchpad.sol
│   ├── ISimpleLaunchpad.sol
│   ├── IUniswapV2FactoryMinimal.sol
│   └── IUniswapV2RouterMinimal.sol
├── libraries/
│   └── RewardsTracker.sol
├── uniswap/
│   └── interfaces/
│       └── IGTELaunchpadV2Pair.sol
├── LaunchpadLPVault.sol
├── LaunchToken.sol
└── SimpleLaunchpad.sol
```

## Files from /perps Directory

**NONE** - The router has no dependencies on any files from the `/perps` directory.

## Notes

1. The router uses the launchpad functionality through:
   - `launchpadBuy()` function (line 210)
   - `launchpadSell()` function (line 195)
   - Constructor parameter for launchpad address (line 99)
   - State variable `ILaunchpad public immutable launchpad` (line 73)

2. The router test files (RouterUnit.t.sol and RouterTestBase.t.sol) also use launchpad functionality but do not introduce any additional dependencies from /perps.

3. Some files in the launchpad directory may import from other directories (like clob, utils, etc.) but those are not part of the /launchpad or /perps directories and are therefore out of scope for this analysis.