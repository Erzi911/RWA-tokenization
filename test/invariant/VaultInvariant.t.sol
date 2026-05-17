// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "BaseTest.t.sol";
import {RWAVault} from "src/RWAVault.sol";

// invariant: totalAssets >= totalSupply * previewRedeem(1e18) / 1e18
// invariant: sum of all user balances == totalSupply
contract VaultInvariantTest is BaseTest {
    address[] internal actors;

    function setUp() public override {
        super.setUp();

        actors = [alice, bob, carol];

        // give everyone tokens and deposit
        for (uint256 i = 0; i < actors.length; i++) {
            _mint(actors[i], 10_000e18);
            _deposit(actors[i], 5_000e18);
        }
    }

    // core ERC-4626 invariant: totalAssets never below what shares represent
    function invariant_totalAssetsGteShares() public view {
        uint256 supply = vault.totalSupply();
        if (supply == 0) return;
        uint256 assetsPerShare = vault.previewRedeem(1e18);
        assertGe(vault.totalAssets() * 1e18, supply * assetsPerShare);
    }

    // share balances sum to totalSupply
    function invariant_totalSupplyMatchesBalances() public view {
        uint256 sum = 0;
        for (uint256 i = 0; i < actors.length; i++) {
            sum += vault.balanceOf(actors[i]);
        }
        assertEq(sum, vault.totalSupply());
    }

    // vault token balance >= totalAssets
    function invariant_vaultHoldsAssets() public view {
        assertGe(token.balanceOf(address(vault)), vault.totalAssets());
    }
}
