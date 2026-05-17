import { BigInt, Bytes } from "@graphprotocol/graph-ts"
import { Deposit, Withdraw } from "../generated/RWAVault/RWAVault"
import { VaultPosition, DepositEvent, WithdrawEvent } from "../generated/schema"

function positionId(vault: Bytes, user: Bytes): string {
  return vault.toHex() + "-" + user.toHex()
}

function loadOrCreatePosition(vault: Bytes, user: Bytes, tokenAddr: string): VaultPosition {
  let id = positionId(vault, user)
  let pos = VaultPosition.load(id)
  if (pos == null) {
    pos = new VaultPosition(id)
    pos.user = user
    pos.token = tokenAddr
    pos.shares = BigInt.fromI32(0)
    pos.totalDeposited = BigInt.fromI32(0)
    pos.totalWithdrawn = BigInt.fromI32(0)
    pos.lastUpdated = BigInt.fromI32(0)
  }
  return pos
}

export function handleDeposit(event: Deposit): void {
  // token id = vault address (simplified — one vault per token in this protocol)
  let pos = loadOrCreatePosition(event.address, event.params.owner, event.address.toHex())
  pos.shares = pos.shares.plus(event.params.shares)
  pos.totalDeposited = pos.totalDeposited.plus(event.params.assets)
  pos.lastUpdated = event.block.timestamp
  pos.save()

  let dep = new DepositEvent(event.transaction.hash.toHex() + "-" + event.logIndex.toString())
  dep.position = pos.id
  dep.sender = event.params.sender
  dep.assets = event.params.assets
  dep.shares = event.params.shares
  dep.blockNumber = event.block.number
  dep.timestamp = event.block.timestamp
  dep.save()
}

export function handleWithdraw(event: Withdraw): void {
  let pos = loadOrCreatePosition(event.address, event.params.owner, event.address.toHex())
  pos.shares = pos.shares.minus(event.params.shares)
  pos.totalWithdrawn = pos.totalWithdrawn.plus(event.params.assets)
  pos.lastUpdated = event.block.timestamp
  pos.save()

  let w = new WithdrawEvent(event.transaction.hash.toHex() + "-" + event.logIndex.toString())
  w.position = pos.id
  w.receiver = event.params.receiver
  w.assets = event.params.assets
  w.shares = event.params.shares
  w.blockNumber = event.block.number
  w.timestamp = event.block.timestamp
  w.save()
}
