// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "forge-std/Script.sol";

import {ERC1967Factory} from "@solady/utils/ERC1967Factory.sol";
import {Operator} from "contracts/utils/Operator.sol";

contract OperatorScript is Script {
    ERC1967Factory factory;

    function run() external {
        address deployer = vm.envAddress("DEPLOYER");
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        factory = ERC1967Factory(vm.envAddress("GTE_FACTORY_TESTNET"));

        vm.createSelectFork("testnet");
        vm.startBroadcast(deployerPrivateKey);

        address operatorLogic = address(new Operator());

        (bool s, bytes memory retData) = address(factory).call{gas: 800_000}(
            abi.encodeCall(ERC1967Factory.deploy, (operatorLogic, deployer))
        ); require(s, "Deployment failed");

        address operatorProxy = abi.decode(retData, (address));


        vm.stopBroadcast();

        console.log("Operator proxy address:", operatorProxy);
    }
}