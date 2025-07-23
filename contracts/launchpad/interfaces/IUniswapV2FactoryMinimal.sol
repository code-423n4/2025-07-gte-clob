pragma solidity 0.8.27;

interface IUniswapV2FactoryMinimal {
    function createPair(address tokenA, address tokenB) external returns (address pair);
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}
