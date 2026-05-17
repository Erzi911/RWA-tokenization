import { useState } from "react"
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi"
import { parseUnits, formatUnits } from "viem"
import { CONTRACTS } from "../lib/config"
import { rwaTokenAbi } from "../abis/RWAToken"
import { rwaVaultAbi } from "../abis/RWAVault"
import { useProtocol } from "../hooks/useProtocol"

export function VaultPanel() {
  const { address } = useAccount()
  const { tokenBalance, vaultShares, vaultTotalAssets, depositCap, refetch } = useProtocol()
  const [amount, setAmount] = useState("")
  const [error, setError] = useState("")

  const { writeContract: approve, data: approveTx } = useWriteContract()
  const { writeContract: deposit, data: depositTx } = useWriteContract()

  const { isLoading: approving } = useWaitForTransactionReceipt({ hash: approveTx })
  const { isLoading: depositing, isSuccess: depositDone } = useWaitForTransactionReceipt({ hash: depositTx })

  if (depositDone) refetch()

  function handleDeposit() {
    setError("")
    if (!address) return setError("Connect your wallet first")
    if (!amount || isNaN(Number(amount))) return setError("Enter a valid amount")

    const parsed = parseUnits(amount, 18)

    if (tokenBalance !== undefined && parsed > tokenBalance) {
      return setError("Insufficient balance")
    }

    // step 1: approve
    approve(
      { address: CONTRACTS.token, abi: rwaTokenAbi, functionName: "approve", args: [CONTRACTS.vault, parsed] },
      {
        onSuccess: () => {
          // step 2: deposit after approval confirmed
          deposit({
            address: CONTRACTS.vault,
            abi: rwaVaultAbi,
            functionName: "deposit",
            args: [parsed, address],
          })
        },
        onError: (e) => setError(e.message),
      }
    )
  }

  return (
    <div className="panel">
      <h2>Vault</h2>
      <div className="stats">
        <div>
          <label>Your Shares</label>
          <span>{vaultShares !== undefined ? formatUnits(vaultShares, 18) : "-"}</span>
        </div>
        <div>
          <label>Total Assets</label>
          <span>{vaultTotalAssets !== undefined ? formatUnits(vaultTotalAssets, 18) : "-"}</span>
        </div>
        <div>
          <label>Deposit Cap</label>
          <span>{depositCap !== undefined ? (depositCap === 0n ? "Unlimited" : formatUnits(depositCap, 18)) : "-"}</span>
        </div>
      </div>

      <div className="deposit-form">
        <input
          type="number"
          placeholder="Amount to deposit"
          value={amount}
          onChange={(e) => setAmount(e.target.value)}
          min="0"
        />
        <button
          onClick={handleDeposit}
          disabled={approving || depositing || !address}
        >
          {approving ? "Approving..." : depositing ? "Depositing..." : "Deposit"}
        </button>
      </div>

      {error && <p className="error">{error}</p>}
      {depositDone && <p className="success">Deposit successful!</p>}
    </div>
  )
}
