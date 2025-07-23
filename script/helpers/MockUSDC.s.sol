pragma solidity ^0.8.0;

import "forge-std/Script.sol";

import {MockERC20} from "forge-std/mocks/MockERC20.sol";

contract MockUSDCScript is Script {
    function run() external {
        if (block.chainid != 1338) revert("Only deploy usdc for testnet!");

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        MockERC20 USDC = new MockERC20();
        USDC.initialize("Mock USDC", "mUSDC", 6);
    }
}
