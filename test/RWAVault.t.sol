// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./BaseTest.t.sol";
import {RWAVault} from "../src/RWAVault.sol";

contract RWAVaultTest is BaseTest {
    uint256 constant AMT = 1_000e18;

    function test_name() public view {
        assertEq(vault.name(), "RWA Gold Vault");
    }

    function test_symbol() public view {
        assertEq(vault.symbol(), "vwGOLD");
    }

    function test_asset() public view {
        assertEq(vault.asset(), address(token));
    }

    function test_owner() public view {
        assertEq(vault.owner(), admin);
    }

    function test_totalAssetsStartsZero() public view {
        assertEq(vault.totalAssets(), 0);
    }

    function test_deposit_givesShares() public {
        _mint(alice, AMT);
        uint256 shares = _deposit(alice, AMT);
        assertGt(shares, 0);
        assertEq(vault.balanceOf(alice), shares);
    }

    function test_deposit_movesTokens() public {
        _mint(alice, AMT);
        _deposit(alice, AMT);
        assertEq(token.balanceOf(address(vault)), AMT);
        assertEq(token.balanceOf(alice), 0);
    }

    function test_deposit_revertsOnZero() public {
        vm.prank(alice);
        vm.expectRevert(RWAVault.ZeroAssets.selector);
        vault.deposit(0, alice);
    }

    function test_deposit_revertsWhenPaused() public {
        _mint(alice, AMT);
        vm.prank(admin);
        vault.setDepositsPaused(true);

        vm.startPrank(alice);
        token.approve(address(vault), AMT);
        vm.expectRevert(RWAVault.DepositsPaused_.selector);
        vault.deposit(AMT, alice);
        vm.stopPrank();
    }

    function test_deposit_revertsWhenCapExceeded() public {
        vm.prank(admin);
        vault.setDepositCap(500e18);
        _mint(alice, AMT);

        vm.startPrank(alice);
        token.approve(address(vault), AMT);
        vm.expectRevert(abi.encodeWithSelector(RWAVault.CapExceeded.selector, AMT, 500e18));
        vault.deposit(AMT, alice);
        vm.stopPrank();
    }

    function test_withdraw_returnsTokens() public {
        _mint(alice, AMT);
        _deposit(alice, AMT);

        uint256 before = token.balanceOf(alice);
        vm.prank(alice);
        vault.withdraw(AMT, alice, alice);
        assertEq(token.balanceOf(alice), before + AMT);
    }

    function test_withdraw_burnsShares() public {
        _mint(alice, AMT);
        _deposit(alice, AMT);
        vm.prank(alice);
        vault.withdraw(AMT, alice, alice);
        assertEq(vault.balanceOf(alice), 0);
        assertEq(vault.totalSupply(), 0);
    }

    function test_withdraw_revertsOnZero() public {
        vm.prank(alice);
        vm.expectRevert(RWAVault.ZeroAssets.selector);
        vault.withdraw(0, alice, alice);
    }

    function test_redeem_1to1_noYield() public {
        _mint(alice, AMT);
        uint256 shares = _deposit(alice, AMT);
        vm.prank(alice);
        uint256 returned = vault.redeem(shares, alice, alice);
        assertEq(returned, AMT);
    }

    function test_redeem_revertsOnZero() public {
        vm.prank(alice);
        vm.expectRevert(RWAVault.ZeroShares.selector);
        vault.redeem(0, alice, alice);
    }

    function test_yield_sharesAppreciate() public {
        _mint(alice, AMT);
        uint256 shares = _deposit(alice, AMT);
        _mint(address(vault), 100e18);
        assertGt(vault.previewRedeem(shares), AMT);
    }

    function test_cap_canBeUpdated() public {
        vm.prank(admin);
        vault.setDepositCap(5_000e18);
        assertEq(vault.depositCap(), 5_000e18);
    }

    function test_cap_zeroIsUnlimited() public {
        vm.prank(admin);
        vault.setDepositCap(0);
        _mint(alice, 1_000_000e18);
        uint256 shares = _deposit(alice, 1_000_000e18);
        assertGt(shares, 0);
    }
}
