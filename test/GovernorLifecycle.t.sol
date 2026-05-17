// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {RWAToken} from "src/RWAToken.sol";
import {RWAVault} from "src/RWAVault.sol";
import {RWAGovernor} from "src/RWAGovernor.sol";
import {Treasury} from "src/Treasury.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// full end-to-end governance lifecycle:
// propose → vote → queue → execute
// also covers: defeat, cancel, quorum failure
contract GovernorLifecycleTest is Test {
    RWAToken    internal token;
    RWAVault    internal vault;
    RWAGovernor internal governor;
    TimelockController internal timelock;
    Treasury    internal treasury;

    address internal admin   = makeAddr("admin");
    address internal alice   = makeAddr("alice");   // whale voter
    address internal bob     = makeAddr("bob");     // whale voter
    address internal carol   = makeAddr("carol");   // small holder
    address internal attacker = makeAddr("attacker");

    // matches RWAGovernor constants
    uint256 constant VOTING_DELAY  = 7_200;   // blocks
    uint256 constant VOTING_PERIOD = 50_400;  // blocks
    uint256 constant TIMELOCK_DELAY = 2 days;
    uint256 constant TOTAL_SUPPLY   = 10_000_000e18;

    // alice + bob hold enough to meet 4% quorum and pass proposals
    uint256 constant ALICE_TOKENS = 3_000_000e18; // 30%
    uint256 constant BOB_TOKENS   = 2_000_000e18; // 20%
    uint256 constant CAROL_TOKENS =   100_000e18; // 1%

    function setUp() public {
        vm.startPrank(admin);

        // 1. token
        token = new RWAToken("RWA Gov Token", "rwGOV", admin);
        token.grantRole(token.MINTER_ROLE(), admin);

        // 2. timelock — proposers/executors set after governor deploy
        address[] memory empty = new address[](0);
        timelock = new TimelockController(TIMELOCK_DELAY, empty, empty, admin);

        // 3. governor
        governor = new RWAGovernor(token, timelock);

        // 4. grant timelock roles to governor
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(governor));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(0)); // anyone can execute
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(governor));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), admin); // renounce admin

        // 5. vault (owned by timelock)
        RWAVault impl = new RWAVault();
        bytes memory initData = abi.encodeCall(
            RWAVault.initialize,
            (address(token), "RWA Vault", "vwRWA", address(timelock), 0)
        );
        vault = RWAVault(address(new ERC1967Proxy(address(impl), initData)));

        // 6. treasury (owned by timelock)
        treasury = new Treasury(address(timelock));

        // 7. mint tokens
        token.mint(alice, ALICE_TOKENS);
        token.mint(bob,   BOB_TOKENS);
        token.mint(carol, CAROL_TOKENS);

        vm.stopPrank();

        // 8. delegate votes
        vm.prank(alice); token.delegate(alice);
        vm.prank(bob);   token.delegate(bob);
        vm.prank(carol); token.delegate(carol);

        // advance one block so checkpoints register
        vm.roll(block.number + 1);
    }

    // ── helpers ──────────────────────────────────────────────────────────────

    function _buildProposal(address target, bytes memory callData, string memory desc)
        internal pure
        returns (address[] memory, uint256[] memory, bytes[] memory, bytes32)
    {
        address[] memory targets = new address[](1);
        uint256[] memory values  = new uint256[](1);
        bytes[]   memory calldatas = new bytes[](1);
        targets[0]    = target;
        values[0]     = 0;
        calldatas[0]  = callData;
        return (targets, values, calldatas, keccak256(bytes(desc)));
    }

    function _propose(address proposer, address target, bytes memory callData, string memory desc)
        internal returns (uint256 proposalId)
    {
        (address[] memory t, uint256[] memory v, bytes[] memory c,) = _buildProposal(target, callData, desc);
        vm.prank(proposer);
        proposalId = governor.propose(t, v, c, desc);
    }

    function _passVotingDelay() internal {
        vm.roll(block.number + VOTING_DELAY + 1);
    }

    function _passVotingPeriod() internal {
        vm.roll(block.number + VOTING_PERIOD + 1);
    }

    function _passTimelockDelay() internal {
        vm.warp(block.timestamp + TIMELOCK_DELAY + 1);
    }

    // ── core lifecycle ────────────────────────────────────────────────────────

    function test_lifecycle_proposeVoteQueueExecute() public {
        // proposal: set vault deposit cap to 1M tokens
        bytes memory callData = abi.encodeCall(vault.setDepositCap, (1_000_000e18));
        string memory desc = "Proposal #1: set vault deposit cap to 1M";

        // --- propose ---
        uint256 proposalId = _propose(alice, address(vault), callData, desc);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Pending));

        // --- voting delay passes ---
        _passVotingDelay();
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Active));

        // --- vote ---
        vm.prank(alice); governor.castVote(proposalId, 1); // For
        vm.prank(bob);   governor.castVote(proposalId, 1); // For
        vm.prank(carol); governor.castVote(proposalId, 0); // Against

        // --- voting period ends ---
        _passVotingPeriod();
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Succeeded));

        // --- queue into timelock ---
        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descHash) =
            _buildProposal(address(vault), callData, desc);
        governor.queue(targets, values, calldatas, descHash);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Queued));

        // --- timelock delay passes ---
        _passTimelockDelay();

        // --- execute ---
        governor.execute(targets, values, calldatas, descHash);
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Executed));

        // --- verify side effect ---
        assertEq(vault.depositCap(), 1_000_000e18);
    }

    // ── defeat path ──────────────────────────────────────────────────────────

    function test_lifecycle_defeated_whenAgainstWins() public {
        bytes memory callData = abi.encodeCall(vault.setDepositCap, (999e18));
        string memory desc = "Proposal #2: malicious cap reduction";

        uint256 proposalId = _propose(alice, address(vault), callData, desc);
        _passVotingDelay();

        // alice votes against her own proposal to test defeat path
        vm.prank(alice); governor.castVote(proposalId, 0); // Against
        vm.prank(bob);   governor.castVote(proposalId, 0); // Against

        _passVotingPeriod();
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));
    }

    // ── quorum failure ────────────────────────────────────────────────────────

    function test_lifecycle_defeated_quorumNotMet() public {
        bytes memory callData = abi.encodeCall(vault.setDepositCap, (500e18));
        string memory desc = "Proposal #3: low participation";

        uint256 proposalId = _propose(alice, address(vault), callData, desc);
        _passVotingDelay();

        // only carol votes (1% of supply) — below 4% quorum
        vm.prank(carol); governor.castVote(proposalId, 1);

        _passVotingPeriod();
        assertEq(uint8(governor.state(proposalId)), uint8(IGovernor.ProposalState.Defeated));
    }

    // ── proposal threshold ────────────────────────────────────────────────────

    function test_propose_revertsIfBelowThreshold() public {
        // attacker has no tokens — can't propose
        bytes memory callData = abi.encodeCall(vault.setDepositCap, (1));
        string memory desc = "Proposal #4: attacker spam";

        (address[] memory t, uint256[] memory v, bytes[] memory c,) =
            _buildProposal(address(vault), callData, desc);

        vm.prank(attacker);
        vm.expectRevert();
        governor.propose(t, v, c, desc);
    }

    // ── double vote protection ────────────────────────────────────────────────

    function test_castVote_revertsOnDoubleVote() public {
        bytes memory callData = abi.encodeCall(vault.setDepositCap, (100e18));
        string memory desc = "Proposal #5: double vote test";

        uint256 proposalId = _propose(alice, address(vault), callData, desc);
        _passVotingDelay();

        vm.prank(alice); governor.castVote(proposalId, 1);
        vm.prank(alice);
        vm.expectRevert();
        governor.castVote(proposalId, 1);
    }

    // ── execute before timelock ───────────────────────────────────────────────

    function test_execute_revertsBeforeTimelockExpiry() public {
        bytes memory callData = abi.encodeCall(vault.setDepositCap, (1_000_000e18));
        string memory desc = "Proposal #6: timelock bypass attempt";

        uint256 proposalId = _propose(alice, address(vault), callData, desc);
        _passVotingDelay();
        vm.prank(alice); governor.castVote(proposalId, 1);
        vm.prank(bob);   governor.castVote(proposalId, 1);
        _passVotingPeriod();

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descHash) =
            _buildProposal(address(vault), callData, desc);
        governor.queue(targets, values, calldatas, descHash);

        // do NOT advance past timelock delay
        vm.expectRevert();
        governor.execute(targets, values, calldatas, descHash);
    }

    // ── vote with reason ─────────────────────────────────────────────────────

    function test_castVoteWithReason() public {
        bytes memory callData = abi.encodeCall(vault.setDepositCap, (1_000_000e18));
        string memory desc = "Proposal #7: vote with reason";

        uint256 proposalId = _propose(alice, address(vault), callData, desc);
        _passVotingDelay();

        vm.prank(alice);
        governor.castVoteWithReason(proposalId, 1, "makes sense for the protocol");

        (uint256 against, uint256 forVotes, uint256 abstain) = governor.proposalVotes(proposalId);
        assertEq(forVotes, ALICE_TOKENS);
        assertEq(against, 0);
        assertEq(abstain, 0);
    }

    // ── treasury proposal ─────────────────────────────────────────────────────

    function test_lifecycle_treasuryWithdrawal() public {
        // fund treasury
        vm.deal(address(treasury), 1 ether);

        bytes memory callData = abi.encodeCall(treasury.withdrawETH, (payable(alice), 0.5 ether));
        string memory desc = "Proposal #8: treasury withdrawal";

        uint256 aliceBalBefore = alice.balance;

        uint256 proposalId = _propose(alice, address(treasury), callData, desc);
        _passVotingDelay();
        vm.prank(alice); governor.castVote(proposalId, 1);
        vm.prank(bob);   governor.castVote(proposalId, 1);
        _passVotingPeriod();

        (address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descHash) =
            _buildProposal(address(treasury), callData, desc);
        governor.queue(targets, values, calldatas, descHash);
        _passTimelockDelay();
        governor.execute(targets, values, calldatas, descHash);

        assertEq(alice.balance, aliceBalBefore + 0.5 ether);
    }
}
