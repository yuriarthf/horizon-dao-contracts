// Utility functions to interact with hardhat evm

import { ethers } from "hardhat";

import { Address } from "../types";

/**
 * @dev Get block timestamp of the current block
 */
export async function now() {
  const blockNumber = await ethers.provider.getBlockNumber();
  return (await ethers.provider.getBlock(blockNumber)).timestamp;
}

/**
 * @dev Set block timestamp of the next block and mine it
 *
 * @param timestamp Timestamp of the next block
 */
export async function setBlockTimestamp(timestamp: number) {
  await ethers.provider.send("evm_mine", [timestamp]);
}

/**
 * @dev Set an account balance
 *
 * @param account Address of the account
 * @param amount Amount in wei to set
 */
export async function setAccountBalance(account: Address, amount: number | string) {
  await ethers.provider.send("hardhat_setBalance", [account, amount]);
}
