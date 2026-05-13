import { http, createConfig } from "wagmi"
import { baseSepolia } from "wagmi/chains"
import { injected, walletConnect } from "wagmi/connectors"

const projectId = import.meta.env.VITE_WALLETCONNECT_PROJECT_ID || ""

export const wagmiConfig = createConfig({
  chains: [baseSepolia],
  connectors: [
    injected(),
    walletConnect({ projectId }),
  ],
  transports: {
    [baseSepolia.id]: http(import.meta.env.VITE_RPC_URL || "https://sepolia.base.org"),
  },
})

export const CONTRACTS = {
  token:    import.meta.env.VITE_TOKEN_ADDRESS    as `0x${string}`,
  vault:    import.meta.env.VITE_VAULT_ADDRESS    as `0x${string}`,
  governor: import.meta.env.VITE_GOVERNOR_ADDRESS as `0x${string}`,
  treasury: import.meta.env.VITE_TREASURY_ADDRESS as `0x${string}`,
}

export const SUBGRAPH_URL = import.meta.env.VITE_SUBGRAPH_URL || ""
