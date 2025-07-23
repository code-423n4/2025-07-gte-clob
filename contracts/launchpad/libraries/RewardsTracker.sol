// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

struct UserRewardData {
    uint96 shares; // User's current share count (up to ~7.9e28)
    uint96 baseRewardDebt; // Used to calculate base token rewards owed
    uint96 quoteRewardDebt; // Used to calculate quote token rewards owed
}

struct RewardPoolData {
    // SLOT 0 //
    uint96 totalShares; // Sum of all user shares
    address quoteAsset; // Secondary reward token
    // SLOT 1 //
    uint128 pendingBaseRewards;
    uint128 pendingQuoteRewards;
    // SLOT 2 //
    uint256 accBaseRewardPerShare; // Accumulated base rewards per share, scaled by 1e12
    uint256 accQuoteRewardPerShare; // Accumulated quote rewards per share, scaled by 1e12
    // SLOT 3 //
    mapping(address => UserRewardData) userRewards; // User-specific reward data
}

struct RewardPoolDataMemory {
    uint96 totalShares; // Sum of all user shares
    address quoteAsset; // Secondary reward token
    uint128 pendingBaseRewards;
    uint128 pendingQuoteRewards; //
    uint256 accBaseRewardPerShare;
    uint256 accQuoteRewardPerShare; // Accumulated quote rewards per share, scaled by 1e12
}

using RewardsTrackerLib for RewardPoolData global;
/**
 * @title RewardsLibrary
 * @dev Library with internal functions for pro rata reward distribution
 */

library RewardsTrackerLib {
    /// @dev sig: 0x9511e79574c9aa195c27c3455b60ba70c9a6efbcfc431ae68b8a3cb4d3764f6c
    event PairRewardsInitialized(address indexed baseAsset, address indexed quoteAsset);
    /// @dev sig: 0x2cbe0649bcb43ba4ace580eeeb0c95a516dec93862fe4cc4e7e60528575cec67
    event BaseRewardsAdded(address indexed baseAsset, uint256 amount);
    /// @dev sig: 0x28590542f9792ca8533cd1beac50e724892009d1f19ed17351f264be124d3293
    event QuoteRewardsAdded(address indexed baseAsset, address indexed quoteAsset, uint256 amount);

    /// @dev sig: 0xe3e46b04
    error ZeroShareStake();
    /// @dev sig: 0xe331bd04
    error ZeroShareClaim();
    /// @dev sig: 0x39996567
    error InsufficientShares();

    // Scale factor used for fixed-point math
    uint128 public constant PRECISION_FACTOR = 1e12;

    function getQuoteAsset(RewardPoolData storage self) internal view returns (address) {
        return self.quoteAsset;
    }

    function getUserData(RewardPoolData storage self, address account) internal view returns (UserRewardData memory) {
        return self.userRewards[account];
    }

    function getRewardsPoolData(RewardPoolData storage self) internal view returns (RewardPoolDataMemory memory pm) {
        pm = RewardPoolDataMemory({
            quoteAsset: self.quoteAsset,
            totalShares: self.totalShares,
            pendingBaseRewards: self.pendingBaseRewards,
            pendingQuoteRewards: self.pendingQuoteRewards,
            accBaseRewardPerShare: self.accBaseRewardPerShare,
            accQuoteRewardPerShare: self.accQuoteRewardPerShare
        });
    }

    function initializePair(RewardPoolData storage self, address baseAsset, address quoteAsset) internal {
        self.quoteAsset = quoteAsset;
        emit PairRewardsInitialized(baseAsset, quoteAsset);
    }

    function addBaseRewards(RewardPoolData storage self, address baseAsset, uint128 amount) internal {
        self.pendingBaseRewards += amount;
        emit BaseRewardsAdded(baseAsset, amount);
    }

    function addQuoteRewards(RewardPoolData storage self, address baseAsset, address quoteAsset, uint128 amount)
        internal
    {
        self.pendingQuoteRewards += amount;
        emit QuoteRewardsAdded(baseAsset, quoteAsset, amount);
    }

    function stake(RewardPoolData storage self, address user, uint96 newShares)
        internal
        returns (uint256 baseAmount, uint256 quoteAmount)
    {
        if (newShares == 0) revert ZeroShareStake();

        (uint256 accBaseRewardsPerShare, uint256 accQuoteRewardsPerShare) = self.update();

        UserRewardData storage userData = self.userRewards[user];

        uint256 existingShares = uint96(userData.shares);

        // Calculate pending rewards before updating shares
        if (existingShares > 0) {
            baseAmount = totalAccRewards(existingShares, accBaseRewardsPerShare) - userData.baseRewardDebt;
            quoteAmount = totalAccRewards(existingShares, accQuoteRewardsPerShare) - userData.quoteRewardDebt;
        }

        // Update user shares
        userData.shares += newShares;
        self.totalShares += newShares;

        // Update reward debts
        userData.baseRewardDebt = uint96(totalAccRewards(existingShares + newShares, accBaseRewardsPerShare));
        userData.quoteRewardDebt = uint96(totalAccRewards(existingShares + newShares, accQuoteRewardsPerShare));
    }

    function unstake(RewardPoolData storage self, address user, uint96 removeShares)
        internal
        returns (uint256 baseAmount, uint256 quoteAmount)
    {
        (uint256 accBaseRewardsPerShare, uint256 accQuoteRewardsPerShare) = self.update();

        UserRewardData storage userData = self.userRewards[user];

        if (removeShares == 0) revert ZeroShareStake();

        uint256 existingShares = uint256(userData.shares);
        if (existingShares < removeShares) revert InsufficientShares();

        // Calculate pending rewards before updating shares
        baseAmount = totalAccRewards(existingShares, accBaseRewardsPerShare) - userData.baseRewardDebt;
        quoteAmount = totalAccRewards(existingShares, accQuoteRewardsPerShare) - userData.quoteRewardDebt;

        // Update user shares
        userData.shares -= removeShares;
        self.totalShares -= removeShares;

        // Update reward debts
        userData.baseRewardDebt = uint96(totalAccRewards(existingShares - removeShares, accBaseRewardsPerShare));
        userData.quoteRewardDebt = uint96(totalAccRewards(existingShares - removeShares, accQuoteRewardsPerShare));
    }

    function claim(RewardPoolData storage self, address user)
        internal
        returns (uint256 baseAmount, uint256 quoteAmount)
    {
        UserRewardData storage userData = self.userRewards[user];
        uint256 shares = uint256(userData.shares);

        if (shares == 0) revert ZeroShareClaim();

        (uint256 accBaseRewardsPerShare, uint256 accQuoteRewardsPerShare) = self.update();

        // Calculate pending rewards
        uint256 totalAccBaseRewards = totalAccRewards(shares, accBaseRewardsPerShare);
        uint256 totalAccQuoteRewards = totalAccRewards(shares, accQuoteRewardsPerShare);

        baseAmount = totalAccBaseRewards - uint128(userData.baseRewardDebt);
        quoteAmount = totalAccQuoteRewards - uint128(userData.quoteRewardDebt);

        // Update reward debts
        userData.baseRewardDebt = uint96(totalAccBaseRewards);
        userData.quoteRewardDebt = uint96(totalAccQuoteRewards);
    }

    function getPendingRewards(RewardPoolData storage self, address user)
        internal
        view
        returns (uint256 baseAmount, uint256 quoteAmount)
    {
        (uint256 accBaseRewardsPerShare, uint256 accQuoteRewardsPerShare) = getAccRewardsPerShare(self);

        UserRewardData storage userData = self.userRewards[user];
        uint256 shares = uint256(userData.shares);

        // Unstaking claims pending rewards, so if no shares, then no pending
        if (shares == 0) return (0, 0);

        baseAmount = totalAccRewards(shares, accBaseRewardsPerShare) - uint128(userData.baseRewardDebt);
        quoteAmount = totalAccRewards(shares, accQuoteRewardsPerShare) - uint128(userData.quoteRewardDebt);
    }

    function totalAccRewards(uint256 shares, uint256 accRewardsPerShare) internal pure returns (uint256) {
        return (shares * accRewardsPerShare) / PRECISION_FACTOR;
    }

    /// @dev Applies the new accrued rewards per share to the rewards state
    function update(RewardPoolData storage self)
        internal
        returns (uint256 newAccBaseRewardsPerShare, uint256 newAccQuoteRewardsPerShare)
    {
        (newAccBaseRewardsPerShare, newAccQuoteRewardsPerShare) = getAccRewardsPerShare(self);

        if (self.pendingBaseRewards > 0) {
            self.accBaseRewardPerShare = newAccBaseRewardsPerShare;
            delete self.pendingBaseRewards;
        }

        if (self.pendingQuoteRewards > 0) {
            self.accQuoteRewardPerShare = newAccQuoteRewardsPerShare;
            delete self.pendingQuoteRewards;
        }
    }

    /// @dev Gets the new accrued rewards per share without updating rewards state
    function getAccRewardsPerShare(RewardPoolData storage self)
        internal
        view
        returns (uint256 accBaseRewardsPerShare, uint256 accQuoteRewardsPerShare)
    {
        uint96 totalShares = self.totalShares;
        if (totalShares == 0) return (self.accBaseRewardPerShare, self.accQuoteRewardPerShare);

        accBaseRewardsPerShare = self.accBaseRewardPerShare;
        accQuoteRewardsPerShare = self.accQuoteRewardPerShare;

        if (self.pendingBaseRewards > 0) {
            accBaseRewardsPerShare += ((self.pendingBaseRewards * PRECISION_FACTOR) / uint128(totalShares));
        }

        if (self.pendingQuoteRewards > 0) {
            accQuoteRewardsPerShare += ((self.pendingQuoteRewards * PRECISION_FACTOR) / uint128(totalShares));
        }
    }
}

/**
 * @title RewardsStorage
 * @dev Storage library for rewards distribution using EIP-1967 pattern
 */
library RewardsTrackerStorage {
    bytes32 internal constant LAUNCH_ASSET_TO_REWARDS_SLOT =
        keccak256(abi.encode(uint256(keccak256("rewardsTrackerPool.self.slot")) - 1)) & ~bytes32(uint256(0xff));

    function rewardPoolSlot(address baseAsset) private pure returns (bytes32) {
        return keccak256(abi.encodePacked(baseAsset, LAUNCH_ASSET_TO_REWARDS_SLOT));
    }

    function getRewardPool(address baseAsset) internal pure returns (RewardPoolData storage p) {
        bytes32 slot = rewardPoolSlot(baseAsset);
        assembly {
            p.slot := slot
        }
    }
}
