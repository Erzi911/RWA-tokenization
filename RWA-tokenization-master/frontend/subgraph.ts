import { SUBGRAPH_URL } from "./config"

async function query<T>(gql: string, variables: Record<string, unknown> = {}): Promise<T> {
  const res = await fetch(SUBGRAPH_URL, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ query: gql, variables }),
  })
  if (!res.ok) throw new Error(`Subgraph request failed: ${res.statusText}`)
  const { data, errors } = await res.json()
  if (errors?.length) throw new Error(errors[0].message)
  return data as T
}

export type Proposal = {
  id: string
  proposer: string
  description: string
  state: number
  forVotes: string
  againstVotes: string
  abstainVotes: string
  createdAt: string
  executedAt: string | null
}

export type MintEvent = {
  id: string
  to: string
  amount: string
  minter: string
  timestamp: string
}

export type VaultPosition = {
  user: string
  shares: string
  totalDeposited: string
  totalWithdrawn: string
}

export async function fetchProposals(): Promise<Proposal[]> {
  const data = await query<{ proposals: Proposal[] }>(`
    query {
      proposals(orderBy: createdAt, orderDirection: desc, first: 20) {
        id proposer description state
        forVotes againstVotes abstainVotes
        createdAt executedAt
      }
    }
  `)
  return data.proposals
}

export async function fetchUserPosition(user: string): Promise<VaultPosition | null> {
  const data = await query<{ vaultPositions: VaultPosition[] }>(`
    query($user: Bytes!) {
      vaultPositions(where: { user: $user }) {
        user shares totalDeposited totalWithdrawn
      }
    }
  `, { user: user.toLowerCase() })
  return data.vaultPositions[0] ?? null
}

export async function fetchRecentMints(): Promise<MintEvent[]> {
  const data = await query<{ mintEvents: MintEvent[] }>(`
    query {
      mintEvents(orderBy: timestamp, orderDirection: desc, first: 10) {
        id to amount minter timestamp
      }
    }
  `)
  return data.mintEvents
}
