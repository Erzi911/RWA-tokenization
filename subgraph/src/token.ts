import { BigInt, Bytes } from "@graphprotocol/graph-ts"
import { TokensMinted, TokensBurned, Transfer } from "../generated/RWAToken/RWAToken"
import { Token, MintEvent } from "../generated/schema"

function loadOrCreateToken(address: Bytes): Token {
  let id = address.toHex()
  let token = Token.load(id)
  if (token == null) {
    token = new Token(id)
    token.name = ""
    token.symbol = ""
    token.totalSupply = BigInt.fromI32(0)
    token.totalMinted = BigInt.fromI32(0)
    token.totalBurned = BigInt.fromI32(0)
  }
  return token
}

export function handleTokensMinted(event: TokensMinted): void {
  let token = loadOrCreateToken(event.address)
  token.totalSupply = token.totalSupply.plus(event.params.amount)
  token.totalMinted = token.totalMinted.plus(event.params.amount)
  token.save()

  let mint = new MintEvent(event.transaction.hash.toHex() + "-" + event.logIndex.toString())
  mint.token = token.id
  mint.to = event.params.to
  mint.amount = event.params.amount
  mint.minter = event.params.minter
  mint.blockNumber = event.block.number
  mint.timestamp = event.block.timestamp
  mint.save()
}

export function handleTokensBurned(event: TokensBurned): void {
  let token = loadOrCreateToken(event.address)
  token.totalSupply = token.totalSupply.minus(event.params.amount)
  token.totalBurned = token.totalBurned.plus(event.params.amount)
  token.save()
}

export function handleTransfer(event: Transfer): void {
  // intentionally minimal — supply tracking done via mint/burn events
}
