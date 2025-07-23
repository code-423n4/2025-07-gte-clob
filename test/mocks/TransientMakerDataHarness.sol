// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {ICLOB} from "contracts/clob/ICLOB.sol";

import {TransientMakerData, MakerCredit} from "contracts/clob/types/TransientMakerData.sol";

contract TransientMakerDataHarness {
    bool public constant IS_SCRIPT = true;

    function addQuoteToken(address maker, uint256 quoteAmount) external {
        TransientMakerData.addQuoteToken(maker, quoteAmount);
    }

    function addBaseToken(address maker, uint256 baseAmount) external {
        TransientMakerData.addBaseToken(maker, baseAmount);
    }

    function getMakerCredits() external returns (MakerCredit[] memory) {
        return TransientMakerData.getMakerCreditsAndClearStorage();
    }

    function getMakers() external returns (address[] memory) {
        return TransientMakerData._getMakersAndClear();
    }

    function getBalance(address maker) external returns (
        uint256 quoteAmount,
        uint256 baseAmount
    ) {
        (
            quoteAmount,
            baseAmount
        ) = TransientMakerData._getBalancesAndClear(maker);
    }
}
