// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;
import {TransientMakerData, TransientMakerDataHarness, MakerCredit} from "../../../mocks/TransientMakerDataHarness.sol";
import {ICLOB} from "contracts/clob/ICLOB.sol";
import {Test} from "forge-std/Test.sol";
import {TestPlus} from "../../../../lib/solady/test/utils/TestPlus.sol";
contract TransientMakerDataTest is Test, TestPlus {
    address maker1 = makeAddr("maker1");
    address maker2 = makeAddr("maker2");
    address maker3 = makeAddr("maker3");

    TransientMakerDataHarness transientMakerData;

    function setUp() public {
        transientMakerData = new TransientMakerDataHarness();
    }

    uint256 maker1QuoteAmount1;
    uint256 maker1QuoteAmount2;
    uint256 maker1BaseAmount1;
    uint256 maker2QuoteAmount;
    uint256 maker2BaseAmount;
    uint256 maker3BaseAmount1;
    uint256 maker3BaseAmount2;
    uint256 makerQuoteAmountInstant;
    uint256 makerBaseAmountInstant;
    uint256 makerQuoteAmountAccount;
    uint256 makerBaseAmountAccount;

    function test_Transient_NoDuplicateMakers_QuoteBase(address maker) public {
        vm.assume(maker != address(0));

        transientMakerData.addQuoteToken(maker, 500);
        transientMakerData.addBaseToken(maker, 1000);

        address[] memory makers = transientMakerData.getMakers();

        assertEq(makers.length, 1, "duplicate maker");
        assertEq(makers[0], maker, "maker address wrong");
    }

    function test_Transient_NoDuplicateMakers_Quote(address maker) public {
        vm.assume(maker != address(0));

        transientMakerData.addQuoteToken(maker, 500);
        transientMakerData.addQuoteToken(maker, 6000);

        address[] memory makers = transientMakerData.getMakers();

        assertEq(makers.length, 1, "duplicate maker");
        assertEq(makers[0], maker, "maker address wrong");
    }

    function test_Transient_NoDuplicateMakers_Base(address maker) public {
        vm.assume(maker != address(0));

        transientMakerData.addBaseToken(maker, 500);
        transientMakerData.addBaseToken(maker, 6000);

        address[] memory makers = transientMakerData.getMakers();

        assertEq(makers.length, 1, "duplicate maker");
        assertEq(makers[0], maker, "maker address wrong");
    }
    function test_TransientMakerCredits(uint256) public {
        uint256 max = type(uint128).max;

        maker1QuoteAmount1 = _hem(_random(), 0, max);
        maker1QuoteAmount2 = _hem(_random(), 0, max);
        maker1BaseAmount1 = _hem(_random(), 0, max);
        maker2QuoteAmount = _hem(_random(), 0, max);
        maker2BaseAmount = _hem(_random(), 0, max);
        maker3BaseAmount1 = _hem(_random(), 0, max);
        maker3BaseAmount2 = _hem(_random(), 0, max);

        transientMakerData.addQuoteToken(maker1, maker1QuoteAmount1);
        transientMakerData.addQuoteToken(maker1, maker1QuoteAmount2);
        transientMakerData.addBaseToken(maker1, maker1BaseAmount1);
        transientMakerData.addQuoteToken(maker2, maker2QuoteAmount);
        transientMakerData.addBaseToken(maker2, maker2BaseAmount);
        transientMakerData.addBaseToken(maker3, maker3BaseAmount1);
        transientMakerData.addBaseToken(maker3, maker3BaseAmount2);

        MakerCredit[] memory makerCredits = transientMakerData.getMakerCredits();

        // STORAGE READ
        assertEq(makerCredits.length, 3, "length wrong");
        assertEq(makerCredits[0].maker, maker1, "maker 1: address wrong");
        assertEq(
            makerCredits[0].quoteAmount, maker1QuoteAmount1 + maker1QuoteAmount2, "maker1: quote amount wrong"
        );
        assertEq(makerCredits[0].baseAmount, maker1BaseAmount1, "maker1: base amount wrong");
        assertEq(makerCredits[1].maker, maker2, "maker 2: address wrong");
        assertEq(makerCredits[1].quoteAmount, maker2QuoteAmount, "maker2: quote amount wrong");
        assertEq(makerCredits[1].baseAmount, maker2BaseAmount, "maker2: base amount wrong");
        assertEq(makerCredits[2].maker, maker3, "maker 3: address wrong");
        assertEq(makerCredits[2].quoteAmount, 0, "maker3: quote amount wrong");
        assertEq(makerCredits[2].baseAmount, maker3BaseAmount1 + maker3BaseAmount2, "maker3: base amount wrong");

        // CLEARED STORAGE
        assertEq(transientMakerData.getMakers().length, 0, "makers not cleared");
        (
            uint256 quoteAmount,
            uint256 baseAmount
        ) = transientMakerData.getBalance(maker1);
        assertEq(quoteAmount, 0, "maker1: quote amount not cleared");
        assertEq(baseAmount, 0, "maker1: base amount not cleared");
        (
            quoteAmount,
            baseAmount
        ) = transientMakerData.getBalance(maker2);
        assertEq(quoteAmount, 0, "maker2: quote amount not cleared");
        assertEq(baseAmount, 0, "maker2: account quote amount not cleared");
        (
            quoteAmount,
            baseAmount
        ) = transientMakerData.getBalance(maker3);
        assertEq(quoteAmount, 0, "maker3: quote amount not cleared");
        assertEq(baseAmount, 0, "maker3: base amount not cleared");
    }

    function test_TransientMakerData_NoCollision(uint256) public {
        uint256 max = type(uint256).max;
        uint256 makerQuoteAmount = _hem(_randomUnique(), 0, max);
        uint256 makerBaseAmount = _hem(_randomUnique(), 0, max);

        transientMakerData.addQuoteToken(maker1, makerQuoteAmount);
        transientMakerData.addBaseToken(maker1, makerBaseAmount);

        MakerCredit[] memory makerCredits = transientMakerData.getMakerCredits();

        // STORAGE READ
        assertEq(makerCredits.length, 1, "length wrong");
        assertEq(makerCredits[0].maker, maker1, "maker 1: address wrong");
        assertEq(makerCredits[0].quoteAmount, makerQuoteAmount, "maker1: quote amount wrong");
        assertEq(makerCredits[0].baseAmount, makerBaseAmount, "maker1: base amount wrong");
    }

    function test_TransientCreditOverflow() public {
        uint256 max = type(uint256).max;

        transientMakerData.addQuoteToken(maker1, max);
        transientMakerData.addBaseToken(maker1, max);

        vm.expectRevert(TransientMakerData.ArithmeticOverflow.selector);
        transientMakerData.addQuoteToken(maker1, 1);

        vm.expectRevert(TransientMakerData.ArithmeticOverflow.selector);
        transientMakerData.addBaseToken(maker1, 1);
    }
}
