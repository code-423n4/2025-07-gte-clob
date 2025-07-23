// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {SafeTransferLib} from "@solady/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "@solady/utils/FixedPointMathLib.sol";
import {IUniswapV2RouterMinimal} from "contracts/launchpad/interfaces/IUniswapV2RouterMinimal.sol";

contract DeployUniV2PairScript is Script {
    using SafeTransferLib for address;
    using FixedPointMathLib for uint256;

    IUniswapV2RouterMinimal uniV2Router;

    address tokenA;
    address tokenB;

    function run() public {
        uniV2Router = IUniswapV2RouterMinimal(vm.envAddress("UNIV2_VANILLA_ROUTER_TESTNET"));

        // tokenA price in tokenB
        uint256 price = 2000e18;

        tokenA = 0x776401b9BC8aAe31A685731B7147D4445fD9FB19; // note: weth
        tokenB = 0xE9b6e75C243B6100ffcb1c66e8f78F96FeeA727F;

        uint256 amountA = price;
        uint256 amountB = 1e18;

        amountA += amountA.fullMulDiv(1000e18, 1e18);
        amountB += amountB.fullMulDiv(1000e18, 1e18);
    }
}
