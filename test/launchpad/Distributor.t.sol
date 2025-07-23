// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;


import "forge-std/Test.sol";
import {Distributor} from "contracts/launchpad/Distributor.sol";
import "contracts/launchpad/libraries/RewardsTracker.sol";

import {Ownable} from "solady/auth/Ownable.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

contract DistributorTest is Test {
    using SafeTransferLib for address;

    Distributor d;

    address launchpad;
    address baseToken;
    address quoteToken;
    address userA;
    address userB;

    function setUp() public {


        launchpad = vm.addr(uint256(keccak256(abi.encode("launchpad"))));
        vm.label(launchpad, "LAUNCHPAD");

        d = new Distributor();
        d.initialize(launchpad);

        baseToken = address(new MockERC20());
        MockERC20(baseToken).initialize("base token", "btn", 18);
        quoteToken = address(new MockERC20());
        MockERC20(quoteToken).initialize("quote token", "qtn", 18);

        deal(baseToken, address(this), 1000 ether);
        deal(quoteToken, address(this), 100 ether);

        userA = vm.addr(uint256(keccak256(bytes("userA"))));
        userB = vm.addr(uint256(keccak256(bytes("userB"))));

    }

    // BASIC TESTS //

    function test_createRewardsPair() public {
        vm.prank(launchpad);
        vm.expectEmit();
        emit RewardsTrackerLib.PairRewardsInitialized(baseToken, quoteToken);

        d.createRewardsPair(baseToken, quoteToken);

        vm.assertEq(d.getRewardsPoolData(baseToken).quoteAsset, quoteToken);
    }

    function test_createRewardsPair_ExpectRevert() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.Unauthorized.selector));
        d.createRewardsPair(baseToken, quoteToken);

        vm.startPrank(launchpad);
        d.createRewardsPair(baseToken, quoteToken);

        vm.expectRevert(abi.encodeWithSelector(Distributor.RewardsExist.selector));
        d.createRewardsPair(baseToken, quoteToken);

        vm.expectRevert(abi.encodeWithSelector(Distributor.RewardsExist.selector));
        d.createRewardsPair(quoteToken, baseToken);

    }

    function test_addRewards() public {
        vm.prank(launchpad);
        d.createRewardsPair(baseToken, quoteToken);

        // Pair is found either way on NOOP
        vm.expectRevert(abi.encodeWithSelector(Distributor.NoSharesToIncentivize.selector));
        d.addRewards(baseToken, quoteToken, 0, 0);
        vm.expectRevert(abi.encodeWithSelector(Distributor.NoSharesToIncentivize.selector));
        d.addRewards(quoteToken, baseToken, 0, 0);

        baseToken.safeApprove(address(d), 100 ether);
        quoteToken.safeApprove(address(d), 100 ether);

        vm.prank(address(launchpad));
        d.increaseStake(baseToken, userA, 1);

        vm.expectEmit();
        emit RewardsTrackerLib.BaseRewardsAdded(baseToken, 50 ether);
        d.addRewards(baseToken, quoteToken, 50 ether, 0);

        assertEq(d.getRewardsPoolData(baseToken).pendingBaseRewards, 50 ether, "base pending normal order incorrect");

        vm.expectEmit();
        emit RewardsTrackerLib.QuoteRewardsAdded(baseToken, quoteToken, 50 ether);
        d.addRewards(baseToken, quoteToken, 0 ether, 50 ether);

        assertEq(d.getRewardsPoolData(baseToken).pendingQuoteRewards, 50 ether, "quote pending normal order incorrect");

        // Works regardless of token order
        vm.expectEmit();
        emit RewardsTrackerLib.BaseRewardsAdded(baseToken, 50 ether);
        d.addRewards(quoteToken, baseToken, 0 ether, 50 ether);

        assertEq(d.getRewardsPoolData(baseToken).pendingBaseRewards, 100 ether, "base pending reverse order incorrect");

        vm.expectEmit();
        emit RewardsTrackerLib.QuoteRewardsAdded(baseToken, quoteToken, 50 ether);
        d.addRewards(quoteToken, baseToken, 50 ether, 0 ether);

        assertEq(d.getRewardsPoolData(baseToken).pendingQuoteRewards, 100 ether, "quote pending reverse order incorrect");
    }

    function testFuzz_addRewards_ExpectRevert(address base, address quote) public {
        vm.assume((base != baseToken && quote != quoteToken) && (base != quoteToken && quote != baseToken));
        vm.prank(launchpad);
        d.createRewardsPair(baseToken, quoteToken);

        vm.expectRevert(abi.encodeWithSelector(Distributor.RewardsDoNotExist.selector));
        d.addRewards(base, quote, 0, 0);
    }

    // STAKING TESTS //

    /// @dev Stakes before the drip such that pending rewards are accrued to total shares upon claiming
    function test_Claim_StakeBeforeDrip() public {
        vm.prank(launchpad);
        d.createRewardsPair(baseToken, quoteToken);

        baseToken.safeApprove(address(d), 100 ether);
        quoteToken.safeApprove(address(d), 100 ether);

        // Increase the stake of userA
        vm.prank(launchpad);
        d.increaseStake(baseToken, userA, 100);
        UserRewardData memory u = d.getUserData(baseToken, userA);

        assertEq(u.shares, 100, "shares dont match");
        assertEq(u.baseRewardDebt, 0, "reward debt before drip should be zero");
        assertEq(u.quoteRewardDebt, 0, "reward debt before drip should be zero");

        // Add rewards to pending
        d.addRewards(baseToken, quoteToken, 50 ether, 0);

        RewardPoolDataMemory memory r = d.getRewardsPoolData(baseToken);

        // Addings rewards makes them pending, they are not accrued until an update is called during a stake or claim action
        assertEq(r.accBaseRewardPerShare, 0);
        assertEq(r.pendingBaseRewards, 50 ether);

        (uint256 pendingBase, uint256 pendingQuote) = d.getPendingRewards(baseToken, userA);

        assertEq(pendingBase, 50 ether);
        assertEq(pendingQuote, 0 ether);

        // rewards
        vm.prank(userA);
        d.claimRewards(baseToken);

        assertEq(baseToken.balanceOf(userA), 50 ether, "pending rewards not distributed");

        r = d.getRewardsPoolData(baseToken);

        // The pending rewards have been claimed and are accrued per share, scaled for precision
        assertEq(r.accBaseRewardPerShare, 50 ether * RewardsTrackerLib.PRECISION_FACTOR / 100, "acc rewards did not accrue");
        assertEq(r.pendingBaseRewards, 0, "pending rewards not drained after claim");
    }

    /// @dev
    function test_ClaimDiscludeSharesBeforePending() public {
        vm.prank(launchpad);
        d.createRewardsPair(baseToken, quoteToken);

        baseToken.safeApprove(address(d), 100 ether);
        quoteToken.safeApprove(address(d), 100 ether);


        // Add rewards to pending (no shares exist)
        vm.expectRevert(abi.encodeWithSelector((Distributor.NoSharesToIncentivize.selector)));
        d.addRewards(baseToken, quoteToken, 50 ether, 0);

        vm.prank(launchpad);
        d.increaseStake(baseToken, userB, 1);
        d.addRewards(baseToken, quoteToken, 50 ether, 0);

        RewardPoolDataMemory memory r = d.getRewardsPoolData(baseToken);

        // Addings rewards makes them pending, they are not accrued until an update is called during a stake or claim action
        assertEq(r.accBaseRewardPerShare, 0);
        assertEq(r.pendingBaseRewards, 50 ether);

        (uint256 pendingBaseUserB, ) = d.getPendingRewards(baseToken, userB);
        assertEq(pendingBaseUserB, 50 ether, "user b's single share should be entitlled to all rewards");

        vm.prank(launchpad);
        d.increaseStake(baseToken, userA, 9);
        UserRewardData memory u = d.getUserData(baseToken, userA);

        assertEq(u.shares, 9);

        // assertEq(u.baseRewardDebt, 0);
        // assertEq(u.quoteRewardDebt, 0);

        // FAILING HERE !! //
        (uint256 pendingBase, uint256 pendingQuote) = d.getPendingRewards(baseToken, userA);

        assertEq(pendingBase, 0, "Staking after adding rewards should entitle 0 pending");
        assertEq(pendingQuote, 0, "Staking after adding rewards should entitle 0 pending");

        d.addRewards(baseToken, quoteToken, 50 ether, 0);

        (pendingBaseUserB, ) = d.getPendingRewards(baseToken, userB);
        (pendingBase,) = d.getPendingRewards(baseToken, userA);

        assertEq(pendingBaseUserB, 55 ether, "UserB pending rewards inaccurate"); // original 50 + 1/10th the stake of another 50
        assertEq(pendingBase, 45 ether, "UserA pending rewards inaccurate");
    }

    function test_MultiUserUnstakeRewardDistribution() public {
        // Setup: UserA has 7 shares, UserB has 3 shares (total 10)
        vm.startPrank(launchpad);
        d.createRewardsPair(baseToken, quoteToken);
        d.increaseStake(baseToken, userA, 7);
        d.increaseStake(baseToken, userB, 3);
        vm.stopPrank();

        baseToken.safeApprove(address(d), 300 ether);


        // Add 100 ether rewards
        d.addRewards(baseToken, quoteToken, uint128(100 ether), 0);


        (uint256 pendingA1, ) = d.getPendingRewards(baseToken, userA);
        (uint256 pendingB1, ) = d.getPendingRewards(baseToken, userB);
        uint128 totalPending = d.getRewardsPoolData(baseToken).pendingBaseRewards;

        // userA and userB should split the 100 eth 70/30 pending
        assertEq(pendingA1, 70 ether, "invalid pending rewards for userA");
        assertEq(pendingB1, 30 ether, "invalid pending rewards for userB");
        assertEq(totalPending, 100 ether, "invalid total pending rewards");

        // UserA unstakes 2/7 shares, leaving them in control of 50% of the future rewards
        uint96 unstakeAmount = 2;
        vm.prank(address(launchpad));
        (uint256 rewardsFromUnstake, ) = d.decreaseStake(baseToken, userA, unstakeAmount);

        // All pending rewards are claimed before the shares are decreased
        assertEq(rewardsFromUnstake, 70 ether, "userA unstake did not result in a full claim of pending");

        UserRewardData memory userDataA = d.getUserData(baseToken, userA);
        UserRewardData memory userDataB = d.getUserData(baseToken, userB);

        assertEq(userDataA.shares, 5, "userA unstake did not succeed correctly");
        assertEq(userDataB.shares, 3);

        // Check pending rewards should be 0 for both after unstake
        (uint256 pendingA2, ) = d.getPendingRewards(baseToken, userA);
        (uint256 pendingB2, ) = d.getPendingRewards(baseToken, userB);
        totalPending = d.getRewardsPoolData(baseToken).pendingBaseRewards;

        // User a should have none pending after the partial unstake, userB should have their original pending
        assertEq(pendingA2, 0, "userA's partial unstake did not claim all pending");
        assertEq(pendingB2, 30 ether, "userB's pending should not be affected by userA unstaking");
        assertEq(totalPending, 0 ether, "total pending should be fully converted to accumulated rewards after userA unstaked");

        // Add another 100 ether rewards
        d.addRewards(baseToken, quoteToken, uint128(100 ether), 0);


        (uint256 pendingA3, ) = d.getPendingRewards(baseToken, userA);
        (uint256 pendingB3, ) = d.getPendingRewards(baseToken, userB);
        totalPending = d.getRewardsPoolData(baseToken).pendingBaseRewards;

        // User a should have their new share of the new rewards pending.
        // User b should have their original pending + their new share of rewards pending
        assertEq(pendingA3, (5 * 100 ether) / 8, "userA's pending after second distribution should be 5/8 of the pool");
        assertEq(pendingB3, (30 ether) + ((3 * 100 ether) / 8), "userB's pending should accunt for their share of both distribution");
        assertEq(totalPending, 100 ether, "total pending should reflect rewards added before any update()s");

        // Double userB's shares
        vm.prank(address(launchpad));
        d.increaseStake(baseToken, userB, 3);

        (uint256 pendingB4,) = d.getPendingRewards(baseToken, userB);
        totalPending = d.getRewardsPoolData(baseToken).pendingBaseRewards;
        assertEq(pendingB4, 0, "Userb's pending was not claimed before an increase stake");
        assertEq(totalPending, 0, "total pending should be fully converted to accumulated rewards after userB increased stake");

        uint256 totalShares = d.getRewardsPoolData(baseToken).totalShares;
        assertEq(totalShares, 11);

        d.addRewards(baseToken, quoteToken, 100 ether, 0);

        (uint256 pendingA5,) = d.getPendingRewards(baseToken, userA);
        (uint256 pendingB5,) = d.getPendingRewards(baseToken, userB);
        totalPending = d.getRewardsPoolData(baseToken).pendingBaseRewards;

        assertEq(pendingA5, ((5 * 100 ether) / 8) + ((5 * 100 ether) / totalShares), "UserA pending does not reflect the last 2 distributions");
        assertEq(pendingB5, (6 * 100 ether)/ totalShares, "USerB pending does not reflect the last distribution");
        assertEq(totalPending, 100 ether, "total pending should reflect any rewards added before any update()s");


        vm.prank(userA);
        (uint256 finalClaimA,) = d.claimRewards(baseToken);
        vm.prank(userB);
        (uint256 finalClaimB,) = d.claimRewards(baseToken);

        assertEq(finalClaimA, pendingA5, "userA final claim != pending");
        assertEq(finalClaimB, pendingB5, "userB final claim != pending");

        (pendingA5,) = d.getPendingRewards(baseToken, userA);
        (pendingB5,) = d.getPendingRewards(baseToken, userB);
        totalPending = d.getRewardsPoolData(baseToken).pendingBaseRewards;

        assertEq(pendingA5, 0);
        assertEq(pendingB5, 0);
        assertEq(totalPending, 0);
    }

    /// @dev Fuzzed test comparing reward accumulation: multiple claims vs single claim
    /// This ensures that claiming frequently vs claiming once yields the same total rewards
    function testFuzz_RewardAccumulation_MultipleClaimsVsSingleClaim(uint256[10] memory swapAmounts) public {
        // Bound swap amounts between 0.1 and 10 ether
        for (uint256 i = 0; i < 10; i++) {
            swapAmounts[i] = bound(swapAmounts[i], 0.1 ether, 10 ether);
        }

        // Setup: Create rewards pair and give both users equal stakes
        vm.prank(launchpad);
        d.createRewardsPair(baseToken, quoteToken);
        
        uint96 stakeAmount = 100; // Equal stakes for both users
        vm.startPrank(launchpad);
        d.increaseStake(baseToken, userA, stakeAmount);
        d.increaseStake(baseToken, userB, stakeAmount);
        vm.stopPrank();

        // Setup token approvals for adding rewards
        baseToken.safeApprove(address(d), type(uint256).max);
        quoteToken.safeApprove(address(d), type(uint256).max);

        // Track total rewards for verification
        uint256 totalUserARewards = 0;
        uint256 totalUserBRewards = 0;
        uint256 totalRewardsAdded = 0;

        // Simulate 10 swaps with fee generation
        for (uint256 i = 0; i < 10; i++) {
            uint256 swapAmount = swapAmounts[i];
            
            // Calculate the fee that would be generated from this swap
            // Using the standard 0.3% swap fee, and assuming all goes to base token rewards
            uint256 swapFee = swapAmount * 3 / 1000; // 0.3% fee
            totalRewardsAdded += swapFee;
            
            // Add the swap fees as rewards to the distributor (simulating pair distributing fees)
            d.addRewards(baseToken, quoteToken, uint128(swapFee), 0);
            
            // Advance block number to simulate time passing
            vm.roll(block.number + 1);
            
            // User A claims rewards after each swap
            vm.prank(userA);
            (uint256 claimedBase,) = d.claimRewards(baseToken);
            totalUserARewards += claimedBase;
            
            // User B doesn't claim yet - will claim all at the end
        }
        
        // User B claims all accumulated rewards at the end
        vm.prank(userB);
        (uint256 finalClaimB, ) = d.claimRewards(baseToken);
        totalUserBRewards = finalClaimB;
        
        // Both users should have received exactly the same total rewards
        // since they had equal stakes throughout the entire period
        assertEq(totalUserARewards, totalUserBRewards, "User A (multiple claims) and User B (single claim) should receive equal total rewards");
        
        // Verify that the total rewards distributed equals half of total rewards added
        // (since there are 2 users with equal stakes, each gets 50%)
        uint256 expectedRewardsPerUser = totalRewardsAdded / 2;
        assertEq(totalUserARewards, expectedRewardsPerUser, "User A should receive exactly 50% of total rewards");
        assertEq(totalUserBRewards, expectedRewardsPerUser, "User B should receive exactly 50% of total rewards");
        
        // Verify no rewards are left unclaimed
        (uint256 pendingA, ) = d.getPendingRewards(baseToken, userA);
        (uint256 pendingB, ) = d.getPendingRewards(baseToken, userB);
        assertEq(pendingA, 0, "User A should have no pending rewards after claiming");
        assertEq(pendingB, 0, "User B should have no pending rewards after claiming");
        
        // Verify all pending rewards in pool are distributed
        uint256 totalPending = d.getRewardsPoolData(baseToken).pendingBaseRewards;
        assertEq(totalPending, 0, "No rewards should remain pending in the pool");
    }

    /// @dev Test to check if skimExcessRewards creates accounting issues
    /// This test attempts to exploit the potential vulnerability in skimExcessRewards
    function test_skimExcessRewards_Overdrawing() public {
        // Setup: Create rewards pair and add user with stake
        vm.prank(launchpad);
        d.createRewardsPair(baseToken, quoteToken);
        
        vm.prank(launchpad);
        d.increaseStake(baseToken, userA, 100);
        
        // Add rewards - this puts 100 ether into the contract and increases totalPendingRewards
        baseToken.safeApprove(address(d), 200 ether);
        d.addRewards(baseToken, quoteToken, 100 ether, 0);
        
        // Verify initial state
        uint256 contractBalanceBefore = baseToken.balanceOf(address(d));
        uint256 totalPendingBefore = d.totalPendingRewards(baseToken);
        (uint256 userPendingBefore,) = d.getPendingRewards(baseToken, userA);
        
        assertEq(contractBalanceBefore, 100 ether, "Contract should have 100 ether");
        assertEq(totalPendingBefore, 100 ether, "Total pending should be 100 ether");
        assertEq(userPendingBefore, 100 ether, "User should have 100 ether pending");
        
        // Now add some "excess" rewards by sending tokens directly to the contract
        // This simulates donations or other ways tokens could end up in the contract
        MockERC20(baseToken).transfer(address(d), 50 ether);
        
        uint256 contractBalanceAfterDonation = baseToken.balanceOf(address(d));
        assertEq(contractBalanceAfterDonation, 150 ether, "Contract should have 150 ether after donation");
        
        // The "excess" amount should be 50 ether (150 - 100 pending)
        uint256 excessAmount = contractBalanceAfterDonation - d.totalPendingRewards(baseToken);
        assertEq(excessAmount, 50 ether, "Excess should be 50 ether");
        
        // Owner skims the excess rewards
        address owner = d.owner();
        uint256 ownerBalanceBefore = baseToken.balanceOf(owner);
        
        vm.prank(owner);
        d.skimExcessRewards(baseToken, excessAmount);
        
        // Check the state after skimming
        uint256 contractBalanceAfterSkim = baseToken.balanceOf(address(d));
        uint256 ownerBalanceAfter = baseToken.balanceOf(owner);
        
        assertEq(ownerBalanceAfter - ownerBalanceBefore, 50 ether, "Owner should have received 50 ether");
        assertEq(contractBalanceAfterSkim, 100 ether, "Contract should have 100 ether after skim");
        
        // Try to claim rewards - this should reveal if there's an accounting issue
        vm.prank(userA);
        try d.claimRewards(baseToken) { 
            assertEq(baseToken.balanceOf(userA), 100 ether, "User should have 100 ether after claim");
            assertEq(d.totalPendingRewards(baseToken), 0 ether, "Total pending should be 0 ether after claim");
        }
        catch {
            assertEq(true, false, "Claim failed due to insufficient pending balance");
        }
    }

}