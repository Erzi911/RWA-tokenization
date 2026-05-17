// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RWAToken} from "src/RWAToken.sol";
import {RWAVault} from "src/RWAVault.sol";
import {ChainlinkAdapter} from "src/ChainlinkAdapter.sol";
import {MockAggregator} from "mocks/MockAggregator.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

abstract contract BaseTest is Test {
    address internal admin  = makeAddr("admin");
    address internal issuer = makeAddr("issuer");
    address internal alice  = makeAddr("alice");
    address internal bob    = makeAddr("bob");
    address internal carol  = makeAddr("carol");

    RWAToken         internal token;
    RWAVault         internal vault;
    ChainlinkAdapter internal adapter;
    MockAggregator   internal mockFeed;

    uint256 internal constant STALENESS = 1 hours;

    function setUp() public virtual {
        vm.startPrank(admin);

        token = new RWAToken("RWA Gold Token", "rwGOLD", admin);
        token.grantRole(token.MINTER_ROLE(), issuer);

        RWAVault impl = new RWAVault();
        bytes memory data = abi.encodeCall(
            RWAVault.initialize,
            (address(token), "RWA Gold Vault", "vwGOLD", admin, 0)
        );
        vault = RWAVault(address(new ERC1967Proxy(address(impl), data)));

        mockFeed = new MockAggregator(8, 1_000e8);
        adapter  = new ChainlinkAdapter(address(mockFeed), STALENESS);

        vm.stopPrank();
    }

    function _mint(address to, uint256 amount) internal {
        vm.prank(issuer);
        token.mint(to, amount);
    }

    function _deposit(address user, uint256 assets) internal returns (uint256 shares) {
        vm.startPrank(user);
        token.approve(address(vault), assets);
        shares = vault.deposit(assets, user);
        vm.stopPrank();
    }
}
