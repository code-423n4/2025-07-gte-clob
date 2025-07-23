// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "forge-std/Script.sol";

import {ERC1967Factory} from "@solady/utils/ERC1967Factory.sol";
import {CLOB} from "contracts/clob/CLOB.sol";
import {ScriptProtector} from "../ScriptProtector.s.sol";
import {UpgradeableBeacon} from "@openzeppelin/proxy/beacon/UpgradeableBeacon.sol";

contract UpgradeCLOBScript is ScriptProtector {
    function run() public override SetupScript /*UpgradeSafeCLOBV0*/ {
        return;
        vm.startBroadcast(deployerPrivateKey);

        // TODO: Update CLOB constructor signature after operator refactoring
        // address clobLogic = address(new CLOB(gteRouterProxy, operatorProxy, 2_147_483_647, address(0), address(0)));

        // (bool s,) = address(beacon).call{gas: 800_000}(abi.encodeCall(UpgradeableBeacon.upgradeTo, (clobLogic)));

        // require(s, "upgrade failed");

        vm.stopBroadcast();
    }
}
