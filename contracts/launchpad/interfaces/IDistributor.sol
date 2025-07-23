pragma solidity 0.8.27;

import {IGTELaunchpadV2Pair} from "./IGTELaunchpadV2Pair.sol";

import {UserRewardData, RewardPoolDataMemory} from "../libraries/RewardsTracker.sol";

interface IDistributor {
    function getUserData(address launchAsset, address account) external view returns (UserRewardData memory);
    function getUserDataForTokens(address[] calldata launchAssets, address account)
        external
        view
        returns (UserRewardData[] memory);
    function increaseStake(address launchAsset, address account, uint96 shares)
        external
        returns (uint256 baseAmount, uint256 quoteAmount);
    function decreaseStake(address launchAsset, address account, uint96 shares)
        external
        returns (uint256 baseAmount, uint256 quoteAmount);
    function claimRewards(address launchAsset) external returns (uint256 baseAmount, uint256 quoteAmount);
    function addRewards(address token0, address token1, uint128 amount0, uint128 amount1) external;
    function createRewardsPair(address launchAsset, address quoteToken) external;

    function endRewards(IGTELaunchpadV2Pair pair) external;
}
