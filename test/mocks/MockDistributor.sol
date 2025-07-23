pragma solidity ^0.8.0;

import {IDistributor, IGTELaunchpadV2Pair} from "contracts/launchpad/interfaces/IDistributor.sol";
import {UserRewardData, RewardPoolDataMemory} from "contracts/launchpad/libraries/RewardsTracker.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

/// @notice because the distributor lies in the middle of the launchpaod and uniswap impleentations, being called by both,
/// we dont want to call it during unit tests for either, justifying a mock
contract MockDistributor is IDistributor {
    using SafeTransferLib for address;

    function endRewards(IGTELaunchpadV2Pair /*pair*/) external pure {
        return;
    }

    function getUserData(address /*launchAsset*/, address /*account*/) external pure returns (UserRewardData memory) {
        UserRewardData memory u;
        return u;
    }

    function getUserDataForTokens(address[] calldata /*launchAssets*/, address /*account*/) external pure returns (UserRewardData[] memory) {
        UserRewardData[] memory u;
        return u;
    }

    function increaseStake(address /*launchAsset*/, address /*account*/, uint96 /*shares*/) external pure returns (uint256 baseAmount, uint256 quoteAmount) {
        baseAmount = 0;
        quoteAmount = 0;
    }

    function decreaseStake(address /*launchAsset*/, address /*account*/, uint96 /*shares*/) external pure returns (uint256 baseAmount, uint256 quoteAmount) {
        baseAmount = 0;
        quoteAmount = 0;
    }

    function claimRewards(address /*launchAsset*/) external pure returns (uint256 baseAmount, uint256 quoteAmount) {
        return (0, 0);
    }

    function addRewards(address token0, address token1, uint128 amount0, uint128 amount1) external {
        if (amount0 > 0) token0.safeTransferFrom(msg.sender, address(this), amount0);
        if (amount1 > 0) token1.safeTransferFrom(msg.sender, address(this), amount0);
    }

    function createRewardsPair(address /*launchAsset*/, address /*quoteToken*/) external pure {
        return;
    }
}