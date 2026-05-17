// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "BaseTest.t.sol";
import {ChainlinkAdapter} from "src/ChainlinkAdapter.sol";
import {MockAggregator} from "mocks/MockAggregator.sol";

contract ChainlinkAdapterTest is BaseTest {
    uint256 constant START_TS = 1_700_000_000;

    function setUp() public override {
        super.setUp();
        vm.warp(START_TS);
        // refresh feed timestamp after warp, otherwise price looks stale
        mockFeed.setAnswer(1_000e8);
    }

    function test_feedSet() public view {
        assertEq(address(adapter.feed()), address(mockFeed));
    }

    function test_stalenessThreshold() public view {
        assertEq(adapter.stalenessThreshold(), STALENESS);
    }

    function test_revertsOnZeroFeed() public {
        vm.expectRevert(ChainlinkAdapter.ZeroAddress.selector);
        new ChainlinkAdapter(address(0), STALENESS);
    }

    function test_revertsOnZeroThreshold() public {
        vm.expectRevert(ChainlinkAdapter.InvalidThreshold.selector);
        new ChainlinkAdapter(address(mockFeed), 0);
    }

    function test_scales8DecTo18Dec() public view {
        assertEq(adapter.latestPrice(), 1_000e18);
    }

    function test_scales18DecFeed() public {
        MockAggregator f = new MockAggregator(18, 2_000e18);
        ChainlinkAdapter a = new ChainlinkAdapter(address(f), STALENESS);
        assertEq(a.latestPrice(), 2_000e18);
    }

    function test_scales6DecFeed() public {
        MockAggregator f = new MockAggregator(6, 500e6);
        ChainlinkAdapter a = new ChainlinkAdapter(address(f), STALENESS);
        assertEq(a.latestPrice(), 500e18);
    }

    function test_reverts_stalePrice() public {
        mockFeed.makeStale(STALENESS + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ChainlinkAdapter.StalePrice.selector,
                START_TS - (STALENESS + 1),
                STALENESS
            )
        );
        adapter.latestPrice();
    }

    function test_passes_freshPrice() public {
        mockFeed.makeStale(STALENESS - 1);
        assertGt(adapter.latestPrice(), 0);
    }

    function test_reverts_negativePrice() public {
        mockFeed.setAnswer(-1);
        vm.expectRevert(abi.encodeWithSelector(ChainlinkAdapter.NegativePrice.selector, int256(-1)));
        adapter.latestPrice();
    }

    function test_reverts_zeroPrice() public {
        mockFeed.setAnswer(0);
        vm.expectRevert(ChainlinkAdapter.ZeroPrice.selector);
        adapter.latestPrice();
    }
}
