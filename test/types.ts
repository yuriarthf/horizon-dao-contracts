// Custom types to be used on every test file

// BigNumberish type (includes string, bytes array, number and BigNumber)
import type { BigNumberish } from "@ethersproject/bignumber";

// Address type
export type Address = string;

// Airdrop type -- Used to build Airdrop trees
export interface Airdrop {
  account: Address;
  amount: BigNumberish;
}
