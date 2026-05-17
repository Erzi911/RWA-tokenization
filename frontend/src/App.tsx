import { WagmiProvider } from "wagmi"
import { QueryClient, QueryClientProvider } from "@tanstack/react-query"
import { wagmiConfig } from "./lib/config"
import { WalletButton } from "./components/WalletButton"
import { VaultPanel } from "./components/VaultPanel"
import { DelegatePanel } from "./components/DelegatePanel"
import { ProposalList } from "./components/ProposalList"
import { useAccount } from "wagmi"
import "./App.css"

const queryClient = new QueryClient()

function Inner() {
  const { isConnected } = useAccount()

  return (
    <div className="app">
      <header>
        <div className="brand">
          <h1>RWA Protocol</h1>
          <span className="network-badge">Base Sepolia</span>
        </div>
        <WalletButton />
      </header>

      {!isConnected ? (
        <div className="connect-prompt">
          <p>Connect your wallet to interact with the protocol.</p>
        </div>
      ) : (
        <main>
          <div className="grid">
            <VaultPanel />
            <DelegatePanel />
          </div>
          <ProposalList />
        </main>
      )}
    </div>
  )
}

export default function App() {
  return (
    <WagmiProvider config={wagmiConfig}>
      <QueryClientProvider client={queryClient}>
        <Inner />
      </QueryClientProvider>
    </WagmiProvider>
  )
}
