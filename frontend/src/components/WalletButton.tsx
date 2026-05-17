import { useAccount, useConnect, useDisconnect, useChainId, useSwitchChain } from "wagmi"
import { baseSepolia } from "wagmi/chains"

export function WalletButton() {
  const { address, isConnected } = useAccount()
  const { connect, connectors, isPending } = useConnect()
  const { disconnect } = useDisconnect()
  const chainId = useChainId()
  const { switchChain } = useSwitchChain()

  const wrongNetwork = isConnected && chainId !== baseSepolia.id

  if (wrongNetwork) {
    return (
      <div className="wrong-network">
        <span>Wrong network</span>
        <button onClick={() => switchChain({ chainId: baseSepolia.id })}>
          Switch to Base Sepolia
        </button>
      </div>
    )
  }

  if (isConnected && address) {
    return (
      <div className="wallet-connected">
        <span className="address">{address.slice(0, 6)}...{address.slice(-4)}</span>
        <button onClick={() => disconnect()}>Disconnect</button>
      </div>
    )
  }

  return (
    <div className="wallet-buttons">
      {connectors.map((c) => (
        <button
          key={c.id}
          onClick={() => connect({ connector: c })}
          disabled={isPending}
        >
          {isPending ? "Connecting..." : c.name}
        </button>
      ))}
    </div>
  )
}
