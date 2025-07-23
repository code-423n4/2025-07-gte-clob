// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import {ICLOB} from "./ICLOB.sol";
import {Limit} from "./types/Book.sol";
import {Order, Side} from "./types/Order.sol";

interface ILimitLens {
    function getLimitsFromTOB(address clob, uint256 numLimits, Side side)
        external
        view
        returns (Limit[] memory, uint256 nextPriceInTicks);

    function getLimits(address clob, uint256 priceInTicks, uint256 numLimits, Side side)
        external
        view
        returns (Limit[] memory, uint256 nextPriceInTicks);

    function getOrdersAtLimits(address clob, uint256[] memory priceInTicks, uint256 numOrdersPerLimit, Side side)
        external
        view
        returns (Order[][] memory orders);
}
