// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {RewardsTrackerLib, RewardPoolData, UserRewardData, RewardPoolDataMemory} from "contracts/launchpad/libraries/RewardsTracker.sol";


// Mock contract to test RewardsTrackerLib
contract MockRewardsTracker {
    using RewardsTrackerLib for RewardPoolData;
    
    RewardPoolData public rewardPool;
    
    function initializePair(address baseAsset, address quoteAsset) external {
        rewardPool.initializePair(baseAsset, quoteAsset);
    }
    
    function addBaseRewards(address baseAsset, uint128 amount) external {
        rewardPool.addBaseRewards(baseAsset, amount);
    }
    
    function addQuoteRewards(address baseAsset, address quoteAsset, uint128 amount) external {
        rewardPool.addQuoteRewards(baseAsset, quoteAsset, amount);
    }
    
    function stake(address user, uint96 newShares) external returns (uint256 baseAmount, uint256 quoteAmount) {
        return rewardPool.stake(user, newShares);
    }
    
    function unstake(address user, uint96 removeShares) external returns (uint256 baseAmount, uint256 quoteAmount) {
        return rewardPool.unstake(user, removeShares);
    }
    
    function claim(address user) external returns (uint256 baseAmount, uint256 quoteAmount) {
        return rewardPool.claim(user);
    }
    
    function getPendingRewards(address user) external view returns (uint256 baseAmount, uint256 quoteAmount) {
        return rewardPool.getPendingRewards(user);
    }
    
    function getQuoteAsset() external view returns (address) {
        return rewardPool.getQuoteAsset();
    }
    
    function getUserData(address account) external view returns (UserRewardData memory) {
        return rewardPool.getUserData(account);
    }
    
    function getRewardsPoolData() external view returns (RewardPoolDataMemory memory) {
        return rewardPool.getRewardsPoolData();
    }
}
