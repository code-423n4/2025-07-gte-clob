// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ILaunchpad} from "../../contracts/launchpad/interfaces/ILaunchpad.sol";
import {ICLOBManager} from "../../contracts/clob/ICLOBManager.sol";
import {IOperator} from "../../contracts/utils/interfaces/IOperator.sol";
import {IDistributor} from "../../contracts/launchpad/interfaces/IDistributor.sol";
import {IUniswapV2RouterMinimal} from "../../contracts/launchpad/interfaces/IUniswapV2RouterMinimal.sol";
import {LaunchpadLPVault} from "../../contracts/launchpad/LaunchpadLPVault.sol";
import {LaunchToken} from "../../contracts/launchpad/LaunchToken.sol";
import {IBondingCurveMinimal} from "../../contracts/launchpad/interfaces/IBondingCurveMinimal.sol";

contract MockLaunchpad is ILaunchpad {
    mapping(address => address) public getTradeableAsset;
    mapping(address => address) public getPairQuoteToken;

    address public immutable rewardDistributor;
    address public owner;
    address public quoteAsset;

    constructor(address _rewardDistributor) {
        rewardDistributor = _rewardDistributor;
        owner = msg.sender;
    }

    function initialize(
        address _owner,
        address _quoteAsset,
        address /* _bondingCurve */,
        address /* _lpVault */,
        bytes memory /* _bondingCurveData */
    ) external {
        owner = _owner;
        quoteAsset = _quoteAsset;
    }

    function updateQuoteAsset(address _quoteAsset) external {
        quoteAsset = _quoteAsset;
    }

    function increaseStake(address /* account */, uint256 /* amount */) external returns (bool) {
        return true;
    }

    function decreaseStake(address /* account */, uint256 /* amount */) external returns (bool) {
        return true;
    }

    function setTradeableAsset(address launchpadAsset, address tradeableAsset) external {
        getTradeableAsset[launchpadAsset] = tradeableAsset;
    }

    function setPairQuoteToken(address launchpadAsset, address quoteToken) external {
        getPairQuoteToken[launchpadAsset] = quoteToken;
    }

    function TOTAL_SUPPLY() external pure returns (uint256) { return 1000000 ether; }
    function BONDING_SUPPLY() external pure returns (uint256) { return 800000 ether; }
    function ABI_VERSION() external pure returns (uint256) { return 1; }
    function gteRouter() external view returns (address) { return address(0); }
    function clobFactory() external view returns (ICLOBManager) { return ICLOBManager(address(0)); }
    function operator() external view returns (IOperator) { return IOperator(address(0)); }
    function distributor() external view returns (IDistributor) { return IDistributor(rewardDistributor); }
    function uniV2Router() external view returns (IUniswapV2RouterMinimal) { return IUniswapV2RouterMinimal(address(0)); }
    function launchpadLPVault() external view returns (LaunchpadLPVault) { return LaunchpadLPVault(address(0)); }

    function launch(string memory /* name */, string memory /* symbol */, string memory /* mediaURI */)
        external payable returns (address) {
        return address(new LaunchToken());
    }

    function buy(BuyData calldata buyData) external returns (uint256, uint256) {
        // Mock implementation that mints tokens to the buyer
        LaunchToken(buyData.token).mint(buyData.amountOutBase);
        LaunchToken(buyData.token).transfer(buyData.recipient, buyData.amountOutBase);
        // Return the quoted amount based on our mock bonding curve
        uint256 quoteSpent = buyData.amountOutBase * 10000;
        return (buyData.amountOutBase, quoteSpent);
    }

    function currentQuoteAsset() external view returns (LaunchToken) {
        return LaunchToken(quoteAsset);
    }

    function currentBondingCurve() external view returns (IBondingCurveMinimal) {
        return IBondingCurveMinimal(address(0));
    }

    function launchFee() external pure returns (uint256) {
        return 0.01 ether;
    }

    function eventNonce() external pure returns (uint256) {
        return 1;
    }

    function launches(address /* launchToken */) external pure returns (LaunchData memory) {
        return LaunchData({
            active: true,
            quote: address(0),
            curve: IBondingCurveMinimal(address(0))
        });
    }

    function sell(address /* account */, address /* token */, address /* recipient */, uint256 amountInBase, uint256 minAmountOutQuote)
        external pure returns (uint256, uint256) {
        // Mock implementation that returns the provided amounts
        return (amountInBase, minAmountOutQuote);
    }

    function updateBondingCurve(address /* newBondingCurve */) external {}

    function quoteBaseForQuote(address /* token */, uint256 quoteAmount, bool /* isBuy */)
        external pure returns (uint256) {
        // Mock 1:1 conversion for simplicity
        return quoteAmount;
    }

    function quoteQuoteForBase(address /* token */, uint256 baseAmount, bool /* isBuy */)
        external pure returns (uint256) {
        // Mock: return 10000x more quote for base (simplified bonding curve simulation)
        return baseAmount * 10000;
    }

    function pullFees() external {}
}