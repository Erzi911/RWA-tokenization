// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "BaseTest.t.sol";

contract VaultFuzzTest is BaseTest {
    // fuzz deposit with arbitrary amounts — shares always > 0 and proportional
    function testFuzz_deposit_sharesProportional(uint256 amount) public {
        amount = bound(amount, 1e6, 1_000_000e18);
        _mint(alice, amount);
        uint256 shares = _deposit(alice, amount);
        assertGt(shares, 0);
        // previewDeposit must match actual shares (ERC-4626 invariant)
        assertEq(vault.previewDeposit(amount), shares);
    }

    // fuzz withdraw — assets returned must match deposited (no yield case)
    function testFuzz_withdraw_roundtrip(uint256 amount) public {
        amount = bound(amount, 1e6, 1_000_000e18);
        _mint(alice, amount);
        _deposit(alice, amount);

        vm.prank(alice);
        uint256 returned = vault.withdraw(amount, alice, alice);
        assertEq(returned, amount);
        assertEq(vault.balanceOf(alice), 0);
    }

    // fuzz redeem — redeeming all shares gives back all assets
    function testFuzz_redeem_allShares(uint256 amount) public {
        amount = bound(amount, 1e6, 1_000_000e18);
        _mint(alice, amount);
        uint256 shares = _deposit(alice, amount);

        vm.prank(alice);
        uint256 assets = vault.redeem(shares, alice, alice);
        assertEq(assets, amount);
    }

    // fuzz deposit cap — never accept more than cap
    function testFuzz_depositCap_enforced(uint256 cap, uint256 amount) public {
        cap = bound(cap, 1e18, 100_000e18);
        amount = bound(amount, cap + 1, cap + 1_000_000e18);

        vm.prank(admin);
        vault.setDepositCap(cap);
        _mint(alice, amount);

        vm.startPrank(alice);
        token.approve(address(vault), amount);
        vm.expectRevert();
        vault.deposit(amount, alice);
        vm.stopPrank();
    }

    // fuzz multiple depositors — total assets = sum of deposits
    function testFuzz_multipleDepositors(uint256 a, uint256 b) public {
        a = bound(a, 1e6, 500_000e18);
        b = bound(b, 1e6, 500_000e18);

        _mint(alice, a);
        _mint(bob, b);
        _deposit(alice, a);
        _deposit(bob, b);

        assertEq(vault.totalAssets(), a + b);
    }
}
