// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

interface IUniV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}
