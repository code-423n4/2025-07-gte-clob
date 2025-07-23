// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "forge-std/Test.sol";

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {IUniswapV2RouterMinimal} from "contracts/launchpad/interfaces/IUniswapV2RouterMinimal.sol";

interface IUniV2Pair {
    function getReserves() external view returns (uint112 _reserve0, uint112 _reserve1, uint32 _blockTimestampLast);
    function token0() external view returns (address);
    function token1() external view returns (address);
}

interface IWETH {
    function deposit() external payable;
}

contract DeployUniV2PairTest is Test {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    IUniswapV2RouterMinimal uniV2Router;

    address weth;
    address cap;

    function setUp() public {
        uniV2Router = IUniswapV2RouterMinimal(vm.envOr("UNIV2_VANILLA_ROUTER_TESTNET", address(0)));
        weth = vm.envOr("WETH_TESTNET", address(0));
        cap = vm.envOr("CAP_TESTNET", address(0));

        if (address(uniV2Router) == address(0)) return;

        vm.createSelectFork("testnet");
    }

    // function test_DeployUniV2Pair() public {
    //     if (address(uniV2Router) == address(0)) {
    //         return;
    //     }

    //     uint256 price = 1885.25e18;

    //     uint256 amountWeth = 1e18;
    //     uint256 amountCap = price;

    //     amountWeth += amountWeth.fullMulDiv(100e18, 1e18);
    //     amountCap += amountCap.fullMulDiv(100e18, 1e18);

    //     address user = 0x1F0bcf1ee59E75D6126C110512AbcF8e97E22672;

    //     deal(cap, user, 100_000_000e18);
    //     deal(weth, user, 100_000_000e18);

    //     vm.startPrank(user);
    //     IWETH(weth).deposit{value: amountWeth}();

    //     weth.safeApprove(address(uniV2Router), type(uint256).max);
    //     cap.safeApprove(address(uniV2Router), type(uint256).max);

    //     console.log(uint256(1_001_000_000_000_000_000_000));
    //     console.log(weth.balanceOf(user));

    //     uniV2Router.addLiquidity(weth, cap, amountWeth, amountCap, amountWeth, amountCap, user, block.timestamp + 1);

    //     IUniV2Pair pair = IUniV2Pair(0xD4526f3670b9A84e6bF8A9CcF974c7Ef3D983908);

    //     (uint256 reserveA, uint256 reserveB,) = pair.getReserves();

    //     uint256 price1 = reserveA.fullMulDiv(1e18, reserveB);
    //     uint256 price2 = reserveB.fullMulDiv(1e18, reserveA);
    //     if (price1 != price) {
    //         assertEq(price2, price);
    //     }
    // }
}
