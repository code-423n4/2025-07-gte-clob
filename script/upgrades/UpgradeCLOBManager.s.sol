// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.27;

import "forge-std/Script.sol";

import {ERC1967Factory} from "@solady/utils/ERC1967Factory.sol";
import {CLOBManager} from "contracts/clob/CLOBManager.sol";

import {ScriptProtector} from "../ScriptProtector.s.sol";

contract UpgradeCLOBManagerScript is ScriptProtector {

    function run() public override /**/ {
        uint16[] memory makerFees = new uint16[](2);
        uint16[] memory takerFees = new uint16[](2);

        makerFees[0] = 750; // .75 bps
        makerFees[1] = 375; // .375 bps
        takerFees[0] = 7500; // 7.5 bps
        takerFees[1] = 3750; // 3.75 bps

        address clobManagerLogic = address(new CLOBManager(address(beacon), operatorProxy));
        vm.startBroadcast(deployerPrivateKey);


        (bool s,) = address(factory).call{gas: 800_000}(
            abi.encodeCall(ERC1967Factory.upgrade, (address(clobManagerProxy), clobManagerLogic))
        );

        require(s, "upgrade failed");

        vm.stopBroadcast();
    }
}
