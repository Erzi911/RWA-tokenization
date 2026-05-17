// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test, console2} from "forge-std/Test.sol";
import {RWAToken} from "src/RWAToken.sol";
import {RWAVault} from "src/RWAVault.sol";
import {RWAGovernor} from "src/RWAGovernor.sol";
import {Treasury} from "src/Treasury.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// fork test — full governance execute on Base Sepolia state
// run with: forge test --match-path test/fork/GovernorFork.t.sol --fork-url $BASE_SEPOLIA_RPC_URL
contract GovernorForkTest is Test {
    RWAToken           internal token;
    RWAVault           internal vault;
    RWAGovernor        internal governor;
    TimelockController internal timelock;
    Treasury           internal treasury;

    address internal admin = makeAddr("admin");
    address internal alice = makeAddr("alice");
    address internal bob   = makeAddr("bob");

    uint256 constant VOTING_DELAY  = 7_200;
    uint256 constant VOTING_PERIOD = 50_400;
    uint256 constant TIMELOCK_DELAY = 2 days;

    function setUp() public {
        vm.startPrank(admin);

        token = new RWAToken("RWA Fork Token", "rwFORK", admin);
        token.grantRole(token.MINTER_ROLE(), admin);

        address[] memory empty = new address[](0);
        timelock = new TimelockController(TIMELOCK_DELAY, empty, empty, admin);
        governor = new RWAGovernor(token, timelock);

        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), admin);

        RWAVault impl = new RWAVault();
        bytes memory initData = abi.encodeCall(
            RWAVault.initialize,
            (address(token), "RWA Fork Vault", "vFORK", address(timelock), 0)
        );
        vault = RWAVault(address(new ERC1967Proxy(address(impl), initData)));

        treasury = new Treasury(address(timelock));

        token.mint(alice, 4_000_000e18); // 40% — enough for quorum
        token.mint(bob,   2_000_000e18); // 20%

        vm.stopPrank();

        vm.prank(alice); token.delegate(alice);
        vm.prank(bob);   token.delegate(bob);
        vm.roll(block.number + 1);
    }

    // full lifecycle on forked network — proves contracts work with real Base Sepolia state
    function test_fullLifecycle() public {
        bytes memory callData = abi.encodeCall(vault.setDepositCap, (5_000_000e18));
        string memory desc    = "fork: set deposit cap to 5M";

        address[] memory targets   = new address[](1);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        targets[0]   = address(vault);
        calldatas[0] = callData;

        // propose
        vm.prank(alice);
        uint256 pid = governor.propose(targets, values, calldatas, desc);
        console2.log("ProposalId:", pid);

        // wait + vote
        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(alice); governor.castVote(pid, 1);
        vm.prank(bob);   governor.castVote(pid, 1);

        // end voting
        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint8(governor.state(pid)), 4); // Succeeded

        // queue
        governor.queue(targets, values, calldatas, keccak256(bytes(desc)));
        assertEq(uint8(governor.state(pid)), 5); // Queued

        // wait timelock
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);

        // execute
        governor.execute(targets, values, calldatas, keccak256(bytes(desc)));
        assertEq(uint8(governor.state(pid)), 7); // Executed

        // side effect confirmed on forked network
        assertEq(vault.depositCap(), 5_000_000e18);
        console2.log("Deposit cap set to:", vault.depositCap());
    }

    function test_receivesAndSendsETH() public {
        vm.deal(address(treasury), 2 ether);
        assertEq(address(treasury).balance, 2 ether);

        // governance proposal to send 1 ETH to bob
        bytes memory callData = abi.encodeCall(treasury.withdrawETH, (payable(bob), 1 ether));
        string memory desc    = "fork: treasury send 1 ETH to bob";

        address[] memory targets   = new address[](1);
        uint256[] memory values    = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        targets[0]   = address(treasury);
        calldatas[0] = callData;

        vm.prank(alice);
        uint256 pid = governor.propose(targets, values, calldatas, desc);

        vm.roll(block.number + VOTING_DELAY + 1);
        vm.prank(alice); governor.castVote(pid, 1);
        vm.prank(bob);   governor.castVote(pid, 1);
        vm.roll(block.number + VOTING_PERIOD + 1);

        governor.queue(targets, values, calldatas, keccak256(bytes(desc)));
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
        governor.execute(targets, values, calldatas, keccak256(bytes(desc)));

        assertEq(bob.balance, 1 ether);
        console2.log("Bob ETH balance:", bob.balance);
    }
}
