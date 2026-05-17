// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "BaseTest.t.sol";
import {RWAToken} from "src/RWAToken.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract RWATokenTest is BaseTest {
    function test_name() public view {
        assertEq(token.name(), "RWA Gold Token");
    }

    function test_symbol() public view {
        assertEq(token.symbol(), "rwGOLD");
    }

    function test_totalSupplyStartsZero() public view {
        assertEq(token.totalSupply(), 0);
    }

    function test_adminHasDefaultAdminRole() public view {
        assertTrue(token.hasRole(token.DEFAULT_ADMIN_ROLE(), admin));
    }

    function test_deployRevertsOnZeroAdmin() public {
        vm.expectRevert(RWAToken.ZeroAddress.selector);
        new RWAToken("T", "T", address(0));
    }

    function test_mint_updatesBalance() public {
        _mint(alice, 1_000e18);
        assertEq(token.balanceOf(alice), 1_000e18);
    }

    function test_mint_updatesTotalSupply() public {
        _mint(alice, 500e18);
        _mint(bob, 300e18);
        assertEq(token.totalSupply(), 800e18);
    }

    function test_mint_emitsEvent() public {
        vm.prank(issuer);
        vm.expectEmit(true, true, false, true);
        emit RWAToken.TokensMinted(alice, 1e18, issuer);
        token.mint(alice, 1e18);
    }

    function test_mint_revertsIfNotMinter() public {
        bytes32 role = token.MINTER_ROLE(); // cache before prank
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, role)
        );
        token.mint(alice, 1e18);
    }

    function test_mint_revertsOnZeroAddress() public {
        vm.prank(issuer);
        vm.expectRevert(RWAToken.ZeroAddress.selector);
        token.mint(address(0), 1e18);
    }

    function test_mint_revertsOnZeroAmount() public {
        vm.prank(issuer);
        vm.expectRevert(RWAToken.ZeroAmount.selector);
        token.mint(alice, 0);
    }

    function test_burn_decreasesBalance() public {
        _mint(alice, 1_000e18);
        bytes32 role = token.BURNER_ROLE(); // cache before prank
        vm.startPrank(admin);
        token.grantRole(role, admin);
        token.burn(alice, 400e18);
        vm.stopPrank();
        assertEq(token.balanceOf(alice), 600e18);
    }

    function test_burn_revertsIfNotBurner() public {
        _mint(alice, 100e18);
        bytes32 role = token.BURNER_ROLE(); // cache before prank
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(IAccessControl.AccessControlUnauthorizedAccount.selector, alice, role)
        );
        token.burn(alice, 100e18);
    }

    function test_transfer() public {
        _mint(alice, 1_000e18);
        vm.prank(alice);
        token.transfer(bob, 250e18);
        assertEq(token.balanceOf(alice), 750e18);
        assertEq(token.balanceOf(bob), 250e18);
    }

    function test_votes_zeroBeforeDelegate() public {
        _mint(alice, 1_000e18);
        assertEq(token.getVotes(alice), 0);
    }

    function test_votes_afterSelfDelegate() public {
        _mint(alice, 1_000e18);
        vm.prank(alice);
        token.delegate(alice);
        assertEq(token.getVotes(alice), 1_000e18);
    }

    function test_votes_delegateToOther() public {
        _mint(alice, 1_000e18);
        vm.prank(alice);
        token.delegate(bob);
        assertEq(token.getVotes(bob), 1_000e18);
        assertEq(token.getVotes(alice), 0);
    }

    function test_votes_updatesOnTransfer() public {
        _mint(alice, 1_000e18);
        vm.prank(alice);
        token.delegate(alice);
        vm.prank(alice);
        token.transfer(bob, 200e18);
        assertEq(token.getVotes(alice), 800e18);
    }

    function test_permit() public {
        uint256 privKey = 0xA11CE;
        address owner = vm.addr(privKey);
        _mint(owner, 100e18);

        uint256 deadline = block.timestamp + 1 hours;
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(
            privKey,
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    token.DOMAIN_SEPARATOR(),
                    keccak256(
                        abi.encode(
                            keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)"),
                            owner,
                            address(vault),
                            uint256(50e18),
                            token.nonces(owner),
                            deadline
                        )
                    )
                )
            )
        );

        token.permit(owner, address(vault), 50e18, deadline, v, r, s);
        assertEq(token.allowance(owner, address(vault)), 50e18);
    }
}
