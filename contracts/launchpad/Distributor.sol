// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

// import {Initializable} from "@solady/utils/Initializable.sol";
import {OwnableRoles} from "@solady/auth/OwnableRoles.sol";
import {SafeCastLib} from "@solady/utils/SafeCastLib.sol";
import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";

import {IDistributor, IGTELaunchpadV2Pair} from "./interfaces/IDistributor.sol";
import "./libraries/RewardsTracker.sol";

/// @notice This contract receives tokens from
contract Distributor is OwnableRoles, IDistributor {
    using SafeTransferLib for address;

    event TotalPendingRewardsIncreased(address indexed asset, uint256 amount);
    event TotalPendingRewardsDecreased(address indexed asset, uint256 amount);

    error Initialized();
    error RewardsExist();
    error RewardsDoNotExist();
    error ClaimAmountExceedsTotalPendingRewards();
    error NoSharesToIncentivize();
    error SkimOverflow();

    uint256 public constant ADMIN_ROLE = _ROLE_0;

    bool private initialized;
    address public launchpad;

    /// @dev metadata to recover donations while preserving pending rewards
    mapping(address => uint256) public totalPendingRewards;

    constructor() {
        _initializeOwner(msg.sender);
    }

    /// @dev There is no init check anywhere else because this contract can't be used until the launchpad address is set
    function initialize(address _launchpad) public onlyOwner {
        if (initialized) revert Initialized();
        launchpad = _launchpad;
        initialized = true;
    }

    modifier onlyLaunchpad() {
        if (msg.sender != launchpad) revert Unauthorized();
        _;
    }

    function skimExcessRewards(address asset, uint256 amount) external onlyOwnerOrRoles(ADMIN_ROLE) {
        if (amount > asset.balanceOf(address(this)) - totalPendingRewards[asset]) revert SkimOverflow();

        asset.safeTransfer(msg.sender, amount);
    }

    function getRewardsPoolData(address launchAsset) external view returns (RewardPoolDataMemory memory) {
        return RewardsTrackerStorage.getRewardPool(launchAsset).getRewardsPoolData();
    }

    function getUserData(address launchAsset, address account) external view returns (UserRewardData memory) {
        return RewardsTrackerStorage.getRewardPool(launchAsset).getUserData(account);
    }

    function getUserDataForTokens(address[] calldata launchAssets, address account)
        external
        view
        returns (UserRewardData[] memory)
    {
        UserRewardData[] memory data = new UserRewardData[](launchAssets.length);

        for (uint256 i = 0; i < launchAssets.length; i++) {
            data[i] = RewardsTrackerStorage.getRewardPool(launchAssets[i]).getUserData(account);
        }
        return data;
    }

    function getPendingRewards(address launchAsset, address account)
        external
        view
        returns (uint256 pendingBase, uint256 pendingQuote)
    {
        RewardPoolData storage rs = RewardsTrackerStorage.getRewardPool(launchAsset);

        return rs.getPendingRewards(account);
    }

    function endRewards(IGTELaunchpadV2Pair pair) external onlyLaunchpad {
        pair.endRewardsAccrual();
    }

    /// @notice Initializes the rewards pair from the launchpad
    /// @dev Neither the launchAsset, nor the quoteAsset can be the baseAsset of an existing reward pool
    function createRewardsPair(address launchAsset, address quoteAsset) external onlyLaunchpad {
        RewardPoolData storage rs = RewardsTrackerStorage.getRewardPool(launchAsset);
        RewardPoolData storage rsq = RewardsTrackerStorage.getRewardPool(quoteAsset);

        // Sanity check in case the admin makes the quote asset of launchpad an existing asset
        if (rs.quoteAsset != address(0) || rsq.quoteAsset != address(0)) revert RewardsExist();

        rs.initializePair(launchAsset, quoteAsset);
    }

    /// @notice Allows rewards to be added to a pool regardless of token order
    /// @dev Pools can only be created once per asset combo, regardless of the order of the assets
    /// Additionally, anyone can add rewards as incentive, even while a pair is still bonding
    function addRewards(address token0, address token1, uint128 amount0, uint128 amount1) external {
        (address launchAsset, address quoteAsset, uint128 launchAssetAmount, uint128 quoteAssetAmount) =
            (token0, token1, amount0, amount1);
        RewardPoolData storage rs = RewardsTrackerStorage.getRewardPool(token0);

        if (rs.quoteAsset == address(0)) {
            rs = RewardsTrackerStorage.getRewardPool(token1);

            if (rs.quoteAsset == address(0)) revert RewardsDoNotExist();

            (launchAsset, quoteAsset, launchAssetAmount, quoteAssetAmount) = (token1, token0, amount1, amount0);
        }

        if (rs.totalShares == 0) revert NoSharesToIncentivize();

        if (launchAssetAmount > 0) {
            rs.addBaseRewards(launchAsset, launchAssetAmount);
            _increaseTotalPending(launchAsset, launchAssetAmount);
            launchAsset.safeTransferFrom(msg.sender, address(this), uint256(launchAssetAmount));
        }

        if (quoteAssetAmount > 0) {
            rs.addQuoteRewards(launchAsset, quoteAsset, quoteAssetAmount);
            _increaseTotalPending(quoteAsset, quoteAssetAmount);
            quoteAsset.safeTransferFrom(msg.sender, address(this), uint256(quoteAssetAmount));
        }
    }

    /// @dev This can only be called while `launchAsset` is bonding, so we dont need to check if the pool exists or is still active
    function increaseStake(address launchAsset, address account, uint96 shares)
        external
        onlyLaunchpad
        returns (uint256 baseAmount, uint256 quoteAmount)
    {
        RewardPoolData storage rs = RewardsTrackerStorage.getRewardPool(launchAsset);

        (baseAmount, quoteAmount) = rs.stake(account, uint96(shares));
        _distributeAssets(launchAsset, baseAmount, rs.quoteAsset, quoteAmount);
    }

    /// @dev This can only be called while `launchAsset` still shares to remove from bonders, so it cannot be called after the pool has been deactivated
    function decreaseStake(address launchAsset, address account, uint96 shares)
        external
        onlyLaunchpad
        returns (uint256 baseAmount, uint256 quoteAmount)
    {
        RewardPoolData storage rs = RewardsTrackerStorage.getRewardPool(launchAsset);

        (baseAmount, quoteAmount) = rs.unstake(account, uint96(shares));
        _distributeAssets(launchAsset, baseAmount, rs.quoteAsset, quoteAmount);
    }

    /// @dev This can be called even after a pool has been deactivated, as accounts may still have pending rewards
    function claimRewards(address launchAsset) external returns (uint256 baseAmount, uint256 quoteAmount) {
        RewardPoolData storage rs = RewardsTrackerStorage.getRewardPool(launchAsset);

        (baseAmount, quoteAmount) = rs.claim(msg.sender);

        _distributeAssets(launchAsset, baseAmount, rs.quoteAsset, quoteAmount);
    }

    function _distributeAssets(address base, uint256 baseAmount, address quote, uint256 quoteAmount) internal {
        if (baseAmount > 0) {
            _decreaseTotalPending(base, baseAmount);
            base.safeTransfer(msg.sender, baseAmount);
        }

        if (quoteAmount > 0) {
            _decreaseTotalPending(quote, quoteAmount);
            quote.safeTransfer(msg.sender, quoteAmount);
        }
    }

    function _increaseTotalPending(address asset, uint256 amount) internal {
        unchecked {
            totalPendingRewards[asset] += amount;
        }

        emit TotalPendingRewardsIncreased(asset, amount);
    }

    function _decreaseTotalPending(address asset, uint256 amount) internal {
        uint256 currTotal = totalPendingRewards[asset];

        if (currTotal < amount) revert ClaimAmountExceedsTotalPendingRewards();

        unchecked {
            totalPendingRewards[asset] -= amount;
        }

        emit TotalPendingRewardsDecreased(asset, amount);
    }
}
