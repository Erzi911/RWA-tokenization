// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./BaseTest.t.sol";
import {RWAVault} from "../src/RWAVault.sol";
import {RWAVaultV2} from "../src/RWAVaultV2.sol";

contract RWAVaultV2Test is BaseTest {
    RWAVaultV2 internal vaultV2;

    function setUp() public override {
        super.setUp();

        // upgrade: deploy V2 impl and upgrade the proxy
        RWAVaultV2 implV2 = new RWAVaultV2();
        vm.prank(admin);
        vault.upgradeToAndCall(address(implV2), "");

        // cast proxy to V2 interface
        vaultV2 = RWAVaultV2(address(vault));
    }

    function test_upgrade_preservesStorage() public {
        // deposit in V1 state (done in BaseTest setUp, vault is fresh here)
        _mint(alice, 1_000e18);
        _deposit(alice, 1_000e18);

        // re-upgrade and check balance survived
        RWAVaultV2 implV2b = new RWAVaultV2();
        vm.prank(admin);
        vaultV2.upgradeToAndCall(address(implV2b), "");

        assertEq(vaultV2.balanceOf(alice), 1_000e18);
    }

    function test_v2_version() public view {
        assertEq(vaultV2.version(), "2.0.0");
    }

    function test_v2_setPerformanceFee() public {
        vm.prank(admin);
        vaultV2.setPerformanceFee(1_000, alice); // 10%
        assertEq(vaultV2.performanceFee(), 1_000);
        assertEq(vaultV2.feeRecipient(), alice);
    }

    function test_v2_feeTooHighReverts() public {
        vm.prank(admin);
        vm.expectRevert(RWAVaultV2.FeeTooHigh.selector);
        vaultV2.setPerformanceFee(3_001, alice);
    }

    function test_v2_depositStillWorks() public {
        _mint(alice, 500e18);
        uint256 shares = _deposit(alice, 500e18);
        assertGt(shares, 0);
    }
}
