// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {LaunchToken} from "../LaunchToken.sol";
import {IBondingCurveMinimal} from "./IBondingCurveMinimal.sol";
import {ICLOBManager} from "../../clob/ICLOBManager.sol";
import {IOperator} from "../../utils/interfaces/IOperator.sol";
import {IDistributor} from "./IDistributor.sol";
import {IUniswapV2RouterMinimal} from "./IUniswapV2RouterMinimal.sol";
import {IUniswapV2FactoryMinimal} from "./IUniswapV2FactoryMinimal.sol";
import {LaunchpadLPVault} from "../LaunchpadLPVault.sol";

interface ILaunchpad {

    struct BuyData {
        address account;
        address token;
        address recipient;
        uint256 amountOutBase;
        uint256 maxAmountInQuote;
    }

    function quoteBaseForQuote(address token, uint256 quoteAmount, bool isBuy)
        external
        view
        returns (uint256 baseAmount);
    function quoteQuoteForBase(address token, uint256 baseAmount, bool isBuy)
        external
        view
        returns (uint256 quoteAmount);

    struct LaunchData {
        bool active;
        address quote;
        IBondingCurveMinimal curve;
    }

    function launch(string memory name, string memory symbol, string memory mediaURI)
        external
        payable
        returns (address token);

    function buy(BuyData calldata buyData)
        external
        returns (uint256 amountOutBaseActual, uint256 amountInQuoteActual);

    function sell(address account, address token, address recipient, uint256 amountInBase, uint256 minAmountOutQuote)
        external
        returns (uint256 amountInBaseActual, uint256 amountOutQuoteActual);

    function updateBondingCurve(address newBondingCurve) external;

    function pullFees() external;

    // slither-disable-next-line naming-convention
    function TOTAL_SUPPLY() external view returns (uint256);

    // slither-disable-next-line naming-convention
    function BONDING_SUPPLY() external view returns (uint256);

    // slither-disable-next-line naming-convention
    function ABI_VERSION() external view returns (uint256);

    function gteRouter() external view returns (address);

    function clobFactory() external view returns (ICLOBManager);

    function operator() external view returns (IOperator);

    function distributor() external view returns (IDistributor);

    function uniV2Router() external view returns (IUniswapV2RouterMinimal);

    function launchpadLPVault() external view returns (LaunchpadLPVault);

    function currentQuoteAsset() external view returns (LaunchToken);

    function currentBondingCurve() external view returns (IBondingCurveMinimal);

    function launchFee() external view returns (uint256);

    function eventNonce() external view returns (uint256);

    function launches(address launchToken) external view returns (LaunchData memory);
}
