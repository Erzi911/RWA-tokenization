import { BigInt, Bytes } from "@graphprotocol/graph-ts"
import {
  ProposalCreated,
  VoteCast,
  ProposalQueued,
  ProposalExecuted,
  ProposalCanceled
} from "../generated/RWAGovernor/RWAGovernor"
import { Proposal, Vote } from "../generated/schema"

export function handleProposalCreated(event: ProposalCreated): void {
  let p = new Proposal(event.params.proposalId.toString())
  p.proposer      = event.params.proposer
  p.targets       = event.params.targets.map<Bytes>(t => t as Bytes)
  p.values        = event.params.values
  p.calldatas     = event.params.calldatas
  p.description   = event.params.description
  p.startBlock    = event.params.voteStart
  p.endBlock      = event.params.voteEnd
  p.state         = 0 // Pending
  p.forVotes      = BigInt.fromI32(0)
  p.againstVotes  = BigInt.fromI32(0)
  p.abstainVotes  = BigInt.fromI32(0)
  p.createdAt     = event.block.timestamp
  p.save()
}

export function handleVoteCast(event: VoteCast): void {
  let p = Proposal.load(event.params.proposalId.toString())
  if (p == null) return

  if (event.params.support == 0)      p.againstVotes = p.againstVotes.plus(event.params.weight)
  else if (event.params.support == 1) p.forVotes     = p.forVotes.plus(event.params.weight)
  else                                p.abstainVotes = p.abstainVotes.plus(event.params.weight)
  p.state = 1 // Active
  p.save()

  let voteId = event.params.proposalId.toString() + "-" + event.params.voter.toHex()
  let v = new Vote(voteId)
  v.proposal    = p.id
  v.voter       = event.params.voter
  v.support     = event.params.support
  v.weight      = event.params.weight
  v.reason      = event.params.reason
  v.blockNumber = event.block.number
  v.save()
}

export function handleProposalQueued(event: ProposalQueued): void {
  let p = Proposal.load(event.params.proposalId.toString())
  if (p == null) return
  p.state = 5 // Queued
  p.eta   = event.params.etaSeconds
  p.save()
}

export function handleProposalExecuted(event: ProposalExecuted): void {
  let p = Proposal.load(event.params.proposalId.toString())
  if (p == null) return
  p.state       = 7 // Executed
  p.executedAt  = event.block.timestamp
  p.save()
}

export function handleProposalCanceled(event: ProposalCanceled): void {
  let p = Proposal.load(event.params.proposalId.toString())
  if (p == null) return
  p.state      = 2 // Canceled
  p.canceledAt = event.block.timestamp
  p.save()
}
