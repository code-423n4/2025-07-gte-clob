// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "forge-std/Script.sol";

import {ERC1967Factory} from "@solady/utils/ERC1967Factory.sol";
import {CLOBManager} from "contracts/clob/CLOBManager.sol";
import {CLOB} from "contracts/clob/CLOB.sol";
import {Operator} from "contracts/utils/Operator.sol";
import {UpgradeableBeacon} from "@openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

contract CLOBManagerScript is Script {
    ERC1967Factory factory;
    address clobManager;
    address gteRouter;
    address clobLogic;
    address operator;
    UpgradeableBeacon beacon;

    function run() external {
        return; // TODO: Update script after operator refactoring
        address deployer = vm.envAddress("DEPLOYER");
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        factory = ERC1967Factory(vm.envAddress("GTE_FACTORY_TESTNET"));
        gteRouter = vm.envAddress("GTE_ROUTER_TESTNET");
        operator = vm.envAddress("GTE_OPERATOR_TESTNET");

        vm.createSelectFork("testnet");

        vm.startBroadcast(deployerPrivateKey);

        clobLogic = address(new CLOB(address(0), gteRouter, address(0), 2_147_483_647));

        beacon = new UpgradeableBeacon(clobLogic, deployer);

        uint16[] memory makerFees = new uint16[](2);
        uint16[] memory takerFees = new uint16[](2);

        makerFees[0] = 750; // .75 bps
        makerFees[1] = 375; // .375 bps
        takerFees[0] = 7500; // 7.5 bps
        takerFees[1] = 3750; // 3.75 bps

        address clobManagerLogic = address(new CLOBManager(address(beacon), operator));

        (bool s, bytes memory retData) = address(factory).call{gas: 2_000_000}(
            abi.encodeCall(ERC1967Factory.deployAndCall, (clobManagerLogic, deployer, (
                abi.encodeCall(CLOBManager.initialize, (deployer))
            )))
        ); require(s, "Deployment failed");

        clobManager = abi.decode(retData, (address));

        vm.stopBroadcast();

        console.log("clob manager:", clobManager);
        console.log("clob beacon:", address(beacon));
    }
}
