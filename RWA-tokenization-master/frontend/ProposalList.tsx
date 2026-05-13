import { useState, useEffect } from "react"
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi"
import { CONTRACTS } from "../lib/config"
import { rwaGovernorAbi } from "../abis/RWAGovernor"
import { fetchProposals, type Proposal } from "../lib/subgraph"
import { formatUnits } from "viem"

const STATE_LABELS: Record<number, string> = {
  0: "Pending",
  1: "Active",
  2: "Canceled",
  3: "Defeated",
  4: "Succeeded",
  5: "Queued",
  6: "Expired",
  7: "Executed",
}

const STATE_COLORS: Record<number, string> = {
  0: "#888",
  1: "#2196f3",
  2: "#f44336",
  3: "#f44336",
  4: "#4caf50",
  5: "#ff9800",
  6: "#888",
  7: "#4caf50",
}

export function ProposalList() {
  const { address } = useAccount()
  const [proposals, setProposals] = useState<Proposal[]>([])
  const [loading, setLoading] = useState(true)
  const [subgraphError, setSubgraphError] = useState("")
  const [votingId, setVotingId] = useState<string | null>(null)
  const [txError, setTxError] = useState("")

  const { writeContract: castVote, data: voteTx } = useWriteContract()
  const { isLoading: voting, isSuccess: voted } = useWaitForTransactionReceipt({ hash: voteTx })

  useEffect(() => {
    fetchProposals()
      .then(setProposals)
      .catch((e) => setSubgraphError(e.message))
      .finally(() => setLoading(false))
  }, [voted])

  function handleVote(proposalId: string, support: number) {
    if (!address) return setTxError("Connect your wallet to vote")
    setTxError("")
    setVotingId(proposalId)
    castVote(
      {
        address: CONTRACTS.governor,
        abi: rwaGovernorAbi,
        functionName: "castVote",
        args: [BigInt(proposalId), support],
      },
      { onError: (e) => setTxError(e.message) }
    )
  }

  if (loading) return <p>Loading proposals from subgraph...</p>
  if (subgraphError) return <p className="error">Subgraph error: {subgraphError}</p>
  if (!proposals.length) return <p>No proposals yet.</p>

  return (
    <div className="panel">
      <h2>Proposals</h2>
      {txError && <p className="error">{txError}</p>}
      <div className="proposal-list">
        {proposals.map((p) => (
          <div key={p.id} className="proposal-card">
            <div className="proposal-header">
              <span
                className="proposal-state"
                style={{ color: STATE_COLORS[p.state] ?? "#888" }}
              >
                {STATE_LABELS[p.state] ?? "Unknown"}
              </span>
              <span className="proposal-id">#{p.id.slice(0, 8)}...</span>
            </div>

            <p className="proposal-desc">{p.description}</p>

            <div className="vote-counts">
              <span className="for">For: {formatUnits(BigInt(p.forVotes), 18)}</span>
              <span className="against">Against: {formatUnits(BigInt(p.againstVotes), 18)}</span>
              <span className="abstain">Abstain: {formatUnits(BigInt(p.abstainVotes), 18)}</span>
            </div>

            {p.state === 1 && (
              <div className="vote-buttons">
                <button
                  onClick={() => handleVote(p.id, 1)}
                  disabled={voting && votingId === p.id}
                  className="btn-for"
                >
                  {voting && votingId === p.id ? "Voting..." : "Vote For"}
                </button>
                <button
                  onClick={() => handleVote(p.id, 0)}
                  disabled={voting && votingId === p.id}
                  className="btn-against"
                >
                  Against
                </button>
                <button
                  onClick={() => handleVote(p.id, 2)}
                  disabled={voting && votingId === p.id}
                  className="btn-abstain"
                >
                  Abstain
                </button>
              </div>
            )}
          </div>
        ))}
      </div>
    </div>
  )
}
