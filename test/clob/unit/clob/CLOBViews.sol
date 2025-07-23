// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import {CLOBTestBase} from "test/clob/utils/CLOBTestBase.sol";
import {ICLOB} from "contracts/clob/ICLOB.sol";
import {CLOBManager} from "contracts/clob/CLOBManager.sol";
import {Side, Order} from "contracts/clob/types/Order.sol";
contract CLOBViewsTest is CLOBTestBase {

    function test_getNextAskOrders() public {
        address user = users[1];
        uint256 startOrderId = 1;
        uint256 currPrice = 1 ether;

        for (uint256 i = 0; i < 6; i++) {
            if (i % 3 == 0) currPrice += 0.5 ether;
            setupOrder(Side.SELL, user, 1 ether, currPrice);
        }

        Order[] memory orders = clob.getNextOrders(startOrderId, 6);
        for (uint256 i = 0; i < orders.length; i++) {
            assertEq(orders[i].id.unwrap(), i + 1);
        }
    }

    function test_getNextBidOrders() public {
        address user = users[1];
        uint256 startOrderId = 1;
        uint256 currPrice = 1 ether;

        for (uint256 i = 0; i < 6; i++) {
            if (i % 3 == 0) currPrice += 0.5 ether;
            setupOrder(Side.BUY, user, 1 ether, currPrice);
        }

        Order[] memory orders = clob.getNextOrders(startOrderId, 6);
        for (uint256 i = 0; i < orders.length; i++) {
            assertEq(orders[i].id.unwrap(), i + 1);
        }
    }
}
