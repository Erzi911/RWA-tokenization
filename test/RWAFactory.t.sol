// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./BaseTest.t.sol";
import {RWAFactory} from "../src/RWAFactory.sol";
import {RWAVault} from "../src/RWAVault.sol";
import {RWAToken} from "../src/RWAToken.sol";

contract RWAFactoryTest is BaseTest {
    RWAFactory internal factory;

    function setUp() public override {
        super.setUp();
        RWAVault impl = new RWAVault();
        vm.prank(admin);
        factory = new RWAFactory(address(impl), admin);
    }

    function test_deployAsset_createsTokenAndVault() public {
        vm.prank(admin);
        (address t, address v) = factory.deployAsset("RWA Silver", "rwSILVER", issuer, 0);
        assertNotEq(t, address(0));
        assertNotEq(v, address(0));
    }

    function test_deployAsset_tokenHasCorrectName() public {
        vm.prank(admin);
        (address t,) = factory.deployAsset("RWA Silver", "rwSILVER", issuer, 0);
        assertEq(RWAToken(t).name(), "RWA Silver");
    }

    function test_deployAsset_issuerCanMint() public {
        vm.prank(admin);
        (address t,) = factory.deployAsset("RWA Silver", "rwSILVER", issuer, 0);
        vm.prank(issuer);
        RWAToken(t).mint(alice, 1_000e18);
        assertEq(RWAToken(t).balanceOf(alice), 1_000e18);
    }

    function test_deployAsset_revertsOnDuplicate() public {
        vm.startPrank(admin);
        factory.deployAsset("RWA Silver", "rwSILVER", issuer, 0);
        bytes32 id = keccak256(abi.encodePacked("RWA Silver", "rwSILVER"));
        vm.expectRevert(abi.encodeWithSelector(RWAFactory.AssetAlreadyExists.selector, id));
        factory.deployAsset("RWA Silver", "rwSILVER", issuer, 0);
        vm.stopPrank();
    }

    function test_totalAssets_incrementsOnDeploy() public {
        vm.startPrank(admin);
        assertEq(factory.totalAssets(), 0);
        factory.deployAsset("RWA Silver", "rwSILVER", issuer, 0);
        assertEq(factory.totalAssets(), 1);
        factory.deployAsset("RWA Gold2", "rwGOLD2", issuer, 0);
        assertEq(factory.totalAssets(), 2);
        vm.stopPrank();
    }

    function test_getAsset_revertsIfNotFound() public {
        bytes32 id = keccak256(abi.encodePacked("NOTEXIST", "NE"));
        vm.expectRevert(abi.encodeWithSelector(RWAFactory.AssetNotFound.selector, id));
        factory.getAsset(id);
    }

    function test_vaultProxy_isUsable() public {
        vm.prank(admin);
        (address t, address v) = factory.deployAsset("RWA Silver", "rwSILVER", issuer, 0);

        vm.prank(issuer);
        RWAToken(t).mint(alice, 1_000e18);

        vm.startPrank(alice);
        RWAToken(t).approve(v, 1_000e18);
        uint256 shares = RWAVault(v).deposit(1_000e18, alice);
        vm.stopPrank();

        assertGt(shares, 0);
    }
}
