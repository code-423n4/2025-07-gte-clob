// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {IUniswapV2RouterMinimal} from "contracts/launchpad/interfaces/IUniswapV2RouterMinimal.sol";
import {MockERC20} from "forge-std/mocks/MockERC20.sol";
import "test/harnesses/ERC20Harness.sol";
import "@solady/utils/SafeTransferLib.sol";
import {LaunchToken} from "contracts/launchpad/LaunchToken.sol";

// import "forge-std/console.sol";
import "forge-std/Test.sol";

contract MockUniV2Router is IUniswapV2RouterMinimal, Test {
    using SafeTransferLib for address;

    bool public constant IS_SCRIPT = true;
    address private immutable _factory;

    constructor(address factory_) {
        _factory = factory_;
    }

    function factory() external view returns (address) {
        return _factory;
    }

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256,
        uint256,
        address,
        uint256 deadline
    ) external returns (uint256, uint256, uint256) {
        MockERC20(tokenA).transferFrom(msg.sender, address(this), amountADesired);
        MockERC20(tokenB).transferFrom(msg.sender, address(this), amountBDesired);

        if (block.timestamp > deadline) revert("expired");

        return (0, 0, 0);
    }

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256, /*amountOutMin*/
        address[] calldata path,
        address to,
        uint256 /*deadline*/
    ) external returns (uint256[] memory amounts) {
        path[0].safeTransferFrom(msg.sender, address(this), amountIn);

        amounts = getAmountsOut(amountIn, path);

        address target = path[path.length - 1];

        uint256 tokens = amounts[amounts.length - 1];

        try ERC20Harness(target).mint(to, tokens) {}
        catch {
            vm.prank(msg.sender);
            try LaunchToken(target).mint(tokens) {}
            catch {
                revert("cant mint mock token for swap. is not an ERC20 harness or LaunchToken");
            }
        }
    }

    function swapTokensForExactTokens(uint256 amountOut, uint256, address[] calldata path, address to, uint256)
        external
        returns (uint256[] memory amounts)
    {
        uint256 amountIn = getAmountIn(amountOut, 0, 0);

        path[0].safeTransferFrom(msg.sender, address(this), amountIn);

        address target = path[path.length - 1];

        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;

        try ERC20Harness(target).mint(to, amountOut) {}
        catch {
            vm.prank(msg.sender);
            try LaunchToken(target).mint(amountOut) {}
            catch {
                revert("cant mint mock token for swap. is not an ERC20 harness or LaunchToken");
            }
        }
    }

    function getAmountIn(uint256 amountOut, uint256, uint256) public pure returns (uint256 amountIn) {
        amountIn = amountOut - amountIn * 1 ether / 0.5 ether;
    }

    function getAmountsOut(uint256 amountIn, address[] memory /*path*/ )
        public
        pure
        returns (uint256[] memory amounts)
    {
        amounts = new uint256[](2);
        amounts[0] = amountIn;
        amounts[1] = amountIn + amountIn * 0.5 ether / 1 ether;
    }
}
