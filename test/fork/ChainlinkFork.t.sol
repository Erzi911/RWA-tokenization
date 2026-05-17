// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {ChainlinkAdapter} from "src/ChainlinkAdapter.sol";

// forge test --match-path test/fork/ChainlinkFork.t.sol --fork-url $BASE_SEPOLIA_RPC_URL -vvv
contract ChainlinkForkTest is Test {
    address constant ETH_USD_FEED = 0x4aDC67696bA383F43DD60A9e78F2C97Fbbfc7cb1;
    uint256 constant STALENESS = 1 hours;

    ChainlinkAdapter internal adapter;

    modifier onlyFork() {
        if (ETH_USD_FEED.code.length == 0) return;
        _;
    }

    function setUp() public {
        if (ETH_USD_FEED.code.length == 0) return;
        adapter = new ChainlinkAdapter(ETH_USD_FEED, STALENESS);
    }

    function test_returnsNonZeroPrice() public onlyFork {
        assertGt(adapter.latestPrice(), 0);
        console2.log("ETH/USD:", adapter.latestPrice());
    }

    function test_priceInReasonableRange() public onlyFork {
        uint256 price = adapter.latestPrice();
        assertGt(price, 100e18);
        assertLt(price, 100_000e18);
    }

    function test_decimalsAre8() public onlyFork {
        assertEq(adapter.feedDecimals(), 8);
    }

    function test_scaledTo18Decimals() public onlyFork {
        assertGt(adapter.latestPrice(), 1e18);
    }
}
