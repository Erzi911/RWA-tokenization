export const rwaTokenAbi = [
  { name: "balanceOf",     type: "function", stateMutability: "view",       inputs: [{ name: "account", type: "address" }],                               outputs: [{ type: "uint256" }] },
  { name: "getVotes",      type: "function", stateMutability: "view",       inputs: [{ name: "account", type: "address" }],                               outputs: [{ type: "uint256" }] },
  { name: "delegates",     type: "function", stateMutability: "view",       inputs: [{ name: "account", type: "address" }],                               outputs: [{ type: "address" }] },
  { name: "approve",       type: "function", stateMutability: "nonpayable", inputs: [{ name: "spender", type: "address" }, { name: "amount", type: "uint256" }], outputs: [{ type: "bool" }] },
  { name: "delegate",      type: "function", stateMutability: "nonpayable", inputs: [{ name: "delegatee", type: "address" }],                             outputs: [] },
  { name: "permit",        type: "function", stateMutability: "nonpayable", inputs: [{ name: "owner", type: "address" }, { name: "spender", type: "address" }, { name: "value", type: "uint256" }, { name: "deadline", type: "uint256" }, { name: "v", type: "uint8" }, { name: "r", type: "bytes32" }, { name: "s", type: "bytes32" }], outputs: [] },
] as const

export const rwaVaultAbi = [
  { name: "balanceOf",    type: "function", stateMutability: "view",       inputs: [{ name: "account", type: "address" }],                               outputs: [{ type: "uint256" }] },
  { name: "totalAssets",  type: "function", stateMutability: "view",       inputs: [],                                                                    outputs: [{ type: "uint256" }] },
  { name: "depositCap",   type: "function", stateMutability: "view",       inputs: [],                                                                    outputs: [{ type: "uint256" }] },
  { name: "depositsPaused", type: "function", stateMutability: "view",     inputs: [],                                                                    outputs: [{ type: "bool" }] },
  { name: "deposit",      type: "function", stateMutability: "nonpayable", inputs: [{ name: "assets", type: "uint256" }, { name: "receiver", type: "address" }], outputs: [{ type: "uint256" }] },
  { name: "redeem",       type: "function", stateMutability: "nonpayable", inputs: [{ name: "shares", type: "uint256" }, { name: "receiver", type: "address" }, { name: "owner", type: "address" }], outputs: [{ type: "uint256" }] },
] as const

export const rwaGovernorAbi = [
  { name: "castVote",         type: "function", stateMutability: "nonpayable", inputs: [{ name: "proposalId", type: "uint256" }, { name: "support", type: "uint8" }], outputs: [{ type: "uint256" }] },
  { name: "proposalVotes",    type: "function", stateMutability: "view",       inputs: [{ name: "proposalId", type: "uint256" }],                          outputs: [{ name: "againstVotes", type: "uint256" }, { name: "forVotes", type: "uint256" }, { name: "abstainVotes", type: "uint256" }] },
  { name: "state",            type: "function", stateMutability: "view",       inputs: [{ name: "proposalId", type: "uint256" }],                          outputs: [{ type: "uint8" }] },
  { name: "votingDelay",      type: "function", stateMutability: "view",       inputs: [],                                                                  outputs: [{ type: "uint256" }] },
  { name: "votingPeriod",     type: "function", stateMutability: "view",       inputs: [],                                                                  outputs: [{ type: "uint256" }] },
  { name: "quorumNumerator",  type: "function", stateMutability: "view",       inputs: [],                                                                  outputs: [{ type: "uint256" }] },
] as const
