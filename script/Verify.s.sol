// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {RWAVault} from "src/RWAVault.sol";
import {RWAGovernor} from "src/RWAGovernor.sol";
import {Treasury} from "src/Treasury.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";

// run after deployment to confirm all invariants hold
// forge script script/Verify.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL
contract Verify is Script {
    function run() external view {
        address vaultProxy = vm.envAddress("VAULT_PROXY");
        address timelockAddr = vm.envAddress("TIMELOCK");
        address governorAddr = vm.envAddress("GOVERNOR");

        TimelockController tl = TimelockController(payable(timelockAddr));
        RWAVault v = RWAVault(vaultProxy);
        RWAGovernor g = RWAGovernor(payable(governorAddr));

        console2.log("=== Post-Deployment Verification ===");

        // vault checks
        _check(v.owner() == timelockAddr,                    "vault.owner == timelock");
        _check(v.depositCap() == 0,                          "vault.depositCap == 0 (unlimited)");
        _check(!v.depositsPaused(),                          "vault.depositsPaused == false");

        // timelock checks
        _check(tl.getMinDelay() == 2 days,                   "timelock.minDelay == 2 days");
        _check(tl.hasRole(tl.PROPOSER_ROLE(), governorAddr), "governor has proposer role");
        _check(tl.hasRole(tl.EXECUTOR_ROLE(), address(0)),   "executor role is open");
        _check(!tl.hasRole(tl.DEFAULT_ADMIN_ROLE(), msg.sender), "deployer lost admin role");

        // governor checks
        _check(g.votingDelay()  == 7_200,  "votingDelay == 7200 blocks");
        _check(g.votingPeriod() == 50_400, "votingPeriod == 50400 blocks");
        _check(g.quorumNumerator() == 4,   "quorum == 4%");

        console2.log("All checks passed.");
    }

    function _check(bool condition, string memory label) internal pure {
        if (condition) {
            console2.log("[PASS]", label);
        } else {
            console2.log("[FAIL]", label);
            revert(string.concat("FAIL: ", label));
        }
    }
}
