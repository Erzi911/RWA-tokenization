import { useReadContracts, useAccount } from "wagmi"
import { CONTRACTS } from "../lib/config"
import { rwaTokenAbi } from "../abis/RWAToken"
import { rwaVaultAbi } from "../abis/RWAVault"
import { rwaGovernorAbi } from "../abis/RWAGovernor"

export function useProtocol() {
  const { address } = useAccount()

  const { data, isLoading, refetch } = useReadContracts({
    contracts: [
      // token balance
      {
        address: CONTRACTS.token,
        abi: rwaTokenAbi,
        functionName: "balanceOf",
        args: [address!],
      },
      // voting power
      {
        address: CONTRACTS.token,
        abi: rwaTokenAbi,
        functionName: "getVotes",
        args: [address!],
      },
      // delegate
      {
        address: CONTRACTS.token,
        abi: rwaTokenAbi,
        functionName: "delegates",
        args: [address!],
      },
      // vault shares
      {
        address: CONTRACTS.vault,
        abi: rwaVaultAbi,
        functionName: "balanceOf",
        args: [address!],
      },
      // vault total assets
      {
        address: CONTRACTS.vault,
        abi: rwaVaultAbi,
        functionName: "totalAssets",
      },
      // vault deposit cap
      {
        address: CONTRACTS.vault,
        abi: rwaVaultAbi,
        functionName: "depositCap",
      },
      // governor voting delay
      {
        address: CONTRACTS.governor,
        abi: rwaGovernorAbi,
        functionName: "votingDelay",
      },
    ],
    query: { enabled: !!address },
  })

  return {
    tokenBalance:   data?.[0]?.result as bigint | undefined,
    votingPower:    data?.[1]?.result as bigint | undefined,
    delegate:       data?.[2]?.result as string | undefined,
    vaultShares:    data?.[3]?.result as bigint | undefined,
    vaultTotalAssets: data?.[4]?.result as bigint | undefined,
    depositCap:     data?.[5]?.result as bigint | undefined,
    isLoading,
    refetch,
  }
}
