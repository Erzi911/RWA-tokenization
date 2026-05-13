// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {RWAToken} from "../src/RWAToken.sol";
import {RWAVault} from "../src/RWAVault.sol";
import {RWAVaultV2} from "../src/RWAVaultV2.sol";
import {RWAFactory} from "../src/RWAFactory.sol";
import {RWAGovernor} from "../src/RWAGovernor.sol";
import {Treasury} from "../src/Treasury.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// idempotent deployment script — run with:
// forge script script/Deploy.s.sol --rpc-url $BASE_SEPOLIA_RPC_URL --broadcast --verify
contract Deploy is Script {
    // deployment config — override via env vars
    string  constant TOKEN_NAME   = "RWA Gold Token";
    string  constant TOKEN_SYMBOL = "rwGOLD";
    uint256 constant TIMELOCK_DELAY = 2 days;
    uint256 constant INITIAL_DEPOSIT_CAP = 0; // unlimited

    struct Deployed {
        address token;
        address vaultImpl;
        address vaultProxy;
        address factory;
        address timelock;
        address governor;
        address treasury;
    }

    function run() external returns (Deployed memory d) {
        uint256 deployerKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address deployer    = vm.addr(deployerKey);

        console2.log("Deployer:  ", deployer);
        console2.log("Chain ID:  ", block.chainid);
        console2.log("---");

        vm.startBroadcast(deployerKey);

        // 1. governance token
        d.token = address(new RWAToken(TOKEN_NAME, TOKEN_SYMBOL, deployer));
        console2.log("RWAToken:         ", d.token);

        // 2. vault implementation (logic contract, never used directly)
        d.vaultImpl = address(new RWAVault());
        console2.log("RWAVault impl:    ", d.vaultImpl);

        // 3. vault proxy — owner will be transferred to timelock after it's deployed
        bytes memory vaultInit = abi.encodeCall(
            RWAVault.initialize,
            (d.token, string.concat("v", TOKEN_NAME), string.concat("v", TOKEN_SYMBOL), deployer, INITIAL_DEPOSIT_CAP)
        );
        d.vaultProxy = address(new ERC1967Proxy(d.vaultImpl, vaultInit));
        console2.log("RWAVault proxy:   ", d.vaultProxy);

        // 4. factory
        d.factory = address(new RWAFactory(d.vaultImpl, deployer));
        console2.log("RWAFactory:       ", d.factory);

        // 5. timelock — deployer as temp admin, roles adjusted below
        address[] memory empty = new address[](0);
        d.timelock = address(new TimelockController(TIMELOCK_DELAY, empty, empty, deployer));
        console2.log("TimelockController:", d.timelock);

        // 6. governor
        d.governor = address(new RWAGovernor(RWAToken(d.token), TimelockController(payable(d.timelock))));
        console2.log("RWAGovernor:      ", d.governor);

        // 7. treasury — owned by timelock from the start
        d.treasury = address(new Treasury(d.timelock));
        console2.log("Treasury:         ", d.treasury);

        // 8. wire up roles

        // governor can propose/cancel in timelock, anyone can execute
        TimelockController tl = TimelockController(payable(d.timelock));
        tl.grantRole(tl.PROPOSER_ROLE(),   d.governor);
        tl.grantRole(tl.CANCELLER_ROLE(),  d.governor);
        tl.grantRole(tl.EXECUTOR_ROLE(),   address(0)); // open execution

        // vault: transfer ownership to timelock
        RWAVault(d.vaultProxy).transferOwnership(d.timelock);

        // token: grant minter role to deployer initially (revoke after initial mint)
        RWAToken(d.token).grantRole(RWAToken(d.token).MINTER_ROLE(), deployer);

        // timelock: revoke deployer admin — DAO has full control now
        tl.revokeRole(tl.DEFAULT_ADMIN_ROLE(), deployer);

        vm.stopBroadcast();

        console2.log("---");
        console2.log("Deployment complete.");
        _verify(d);
    }

    // sanity checks after deployment
    function _verify(Deployed memory d) internal view {
        TimelockController tl = TimelockController(payable(d.timelock));

        require(RWAVault(d.vaultProxy).owner() == d.timelock,       "vault owner != timelock");
        require(tl.hasRole(tl.PROPOSER_ROLE(), d.governor),         "governor not proposer");
        require(tl.hasRole(tl.EXECUTOR_ROLE(), address(0)),         "executor role not open");
        require(!tl.hasRole(tl.DEFAULT_ADMIN_ROLE(), vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"))),
            "deployer still has admin role");

        console2.log("All post-deploy checks passed.");
    }
}
