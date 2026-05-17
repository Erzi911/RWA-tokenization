import { useState } from "react"
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi"
import { isAddress, formatUnits } from "viem"
import { CONTRACTS } from "../lib/config"
import { rwaTokenAbi } from "../abis/RWAToken"
import { useProtocol } from "../hooks/useProtocol"

export function DelegatePanel() {
  const { address } = useAccount()
  const { tokenBalance, votingPower, delegate, refetch } = useProtocol()
  const [target, setTarget] = useState("")
  const [error, setError] = useState("")

  const { writeContract, data: tx } = useWriteContract()
  const { isLoading, isSuccess } = useWaitForTransactionReceipt({ hash: tx })

  if (isSuccess) refetch()

  function handleDelegate() {
    setError("")
    if (!address) return setError("Connect wallet first")
    const to = target.trim() || address
    if (!isAddress(to)) return setError("Invalid address")

    writeContract(
      { address: CONTRACTS.token, abi: rwaTokenAbi, functionName: "delegate", args: [to] },
      { onError: (e) => setError(e.message) }
    )
  }

  function selfDelegate() {
    if (!address) return
    setTarget(address)
  }

  return (
    <div className="panel">
      <h2>Voting Power</h2>
      <div className="stats">
        <div>
          <label>Token Balance</label>
          <span>{tokenBalance !== undefined ? formatUnits(tokenBalance, 18) : "-"}</span>
        </div>
        <div>
          <label>Voting Power</label>
          <span>{votingPower !== undefined ? formatUnits(votingPower, 18) : "-"}</span>
        </div>
        <div>
          <label>Delegated To</label>
          <span className="address">
            {delegate
              ? delegate === address
                ? "Self"
                : `${delegate.slice(0, 6)}...${delegate.slice(-4)}`
              : "Not delegated"}
          </span>
        </div>
      </div>

      <div className="delegate-form">
        <input
          placeholder="Delegate to address (leave blank for self)"
          value={target}
          onChange={(e) => setTarget(e.target.value)}
        />
        <div className="delegate-actions">
          <button onClick={selfDelegate} className="btn-secondary">Self</button>
          <button onClick={handleDelegate} disabled={isLoading || !address}>
            {isLoading ? "Delegating..." : "Delegate"}
          </button>
        </div>
      </div>

      {error && <p className="error">{error}</p>}
      {isSuccess && <p className="success">Delegation updated!</p>}
    </div>
  )
}
