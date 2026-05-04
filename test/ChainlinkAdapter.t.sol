// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseTest} from "./BaseTest.t.sol";
import {ChainlinkAdapter} from "../src/ChainlinkAdapter.sol";
import {MockAggregator} from "./mocks/MockAggregator.sol";

contract ChainlinkAdapterTest is BaseTest {
    function test_feedSet() public view {
        assertEq(address(adapter.feed()), address(mockFeed));
    }

    function test_stalenessThreshold() public view {
        assertEq(adapter.stalenessThreshold(), STALENESS);
    }

    function test_revertsOnZeroFeed() public view {
        vm.expectRevert(ChainlinkAdapter.ZeroAddress.selector);
        new ChainlinkAdapter(address(0), STALENESS);
    }

    function test_revertsOnZeroThreshold() public view {
        vm.expectRevert(ChainlinkAdapter.InvalidThreshold.selector);
        new ChainlinkAdapter(address(mockFeed), 0);
    }

    function test_scales8DecTo18Dec() public view {
        // feed returns 1_000e8, should get back 1_000e18
        assertEq(adapter.latestPrice(), 1_000e18);
    }

    function test_scales18DecFeed() public view {
        MockAggregator f = new MockAggregator(18, 2_000e18);
        ChainlinkAdapter a = new ChainlinkAdapter(address(f), STALENESS);
        assertEq(a.latestPrice(), 2_000e18);
    }

    function test_scales6DecFeed() public view {
        MockAggregator f = new MockAggregator(6, 500e6);
        ChainlinkAdapter a = new ChainlinkAdapter(address(f), STALENESS);
        assertEq(a.latestPrice(), 500e18);
    }

    function test_reverts_stalePrice() public view {
        mockFeed.makeStale(STALENESS + 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ChainlinkAdapter.StalePrice.selector,
                block.timestamp - (STALENESS + 1),
                STALENESS
            )
        );
        adapter.latestPrice();
    }

    function test_passes_freshPrice() public view {
        mockFeed.makeStale(STALENESS - 1);
        assertGt(adapter.latestPrice(), 0);
    }

    function test_reverts_negativePrice() public view {
        mockFeed.setAnswer(-1);
        vm.expectRevert(abi.encodeWithSelector(ChainlinkAdapter.NegativePrice.selector, int256(-1)));
        adapter.latestPrice();
    }

    function test_reverts_zeroPrice() public view {
        mockFeed.setAnswer(0);
        vm.expectRevert(ChainlinkAdapter.ZeroPrice.selector);
        adapter.latestPrice();
    }
}
