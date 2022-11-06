// airdrop_tree.ts: Implements PioneerTree class to be used to
// generate merkle roots to be used for airdrops

// Import MerkleTree class to build the airdrop merkle tree
import { MerkleTree } from "merkletreejs";

// Ethers for keccak256 hash
import { ethers, BigNumber, BigNumberish } from "ethers";

// Import types
import type { Address, Airdrop } from "../../types";

/**
 * @dev Used to get the airdrop whitelist merkle roots, containing accounts
 *    and amounts to airdrop.
 */
export class AirdropTree {
  readonly airdropTree: MerkleTree;
  readonly airdrops: Airdrop[];

  /**
   * @dev Build airdrop merkle tree
   * @param airdrops List of Airdrop objects (containing account and amount)
   */
  constructor(airdrops: Airdrop[]) {
    this.airdrops = airdrops;
    this.airdropTree = new MerkleTree(this.leaves, ethers.utils.keccak256, { sortPairs: true });
  }

  /**
   * @dev Get airdrop merkle tree leaves (whitelisted addresses)
   */
  get leaves() {
    return this.airdrops.map((airdrop) =>
      Buffer.from(
        ethers.utils
          .keccak256(ethers.utils.solidityPack(["address", "uint256"], [airdrop.account, airdrop.amount]))
          .substring(2),
        "hex",
      ),
    );
  }

  /**
   * @dev Get airdrop merkle tree root
   */
  get root() {
    return this.airdropTree.getHexRoot();
  }

  /**
   * @dev Get airdrop accounts
   */
  get accounts() {
    return this.airdrops.map(({ account }) => account);
  }

  /**
   * @dev Get airdrop amounts
   */
  get amounts() {
    return this.airdrops.map(({ amount }) => amount);
  }

  /**
   * @dev Get airdrop length
   */
  get airdropLength() {
    return this.airdrops.length;
  }

  /**
   * @dev Get airdrop total amount
   */
  get totalAmount() {
    return this.airdrops.reduce((previousAmount, { amount }) => previousAmount.add(amount), BigNumber.from(0));
  }

  /**
   * @dev Get merkle proofs for a given leaf
   * @param leaf Keccak256 hash of a airdrop merkle tree account
   */
  proofs(leaf: Buffer): string[] {
    return this.airdropTree.getHexProof(leaf);
  }

  /**
   * @dev Get airdrop account at index
   * @param index Index number
   * @returns Airdrop account
   */
  getAccountAt(index: number): Address | undefined {
    return this.airdrops[index].account;
  }

  /**
   * @dev Get airdrop amount at index
   * @param index Index number
   * @returns Airdrop amount
   */
  getAmountAt(index: number): BigNumberish | undefined {
    return this.airdrops[index].amount;
  }

  /**
   * @dev Get airdrop amount associated with an account
   * @param account Account address
   * @return Airdrop amount for the given account
   */
  amountFor(account: Address): BigNumberish {
    const airdrop = this.airdrops.find(({ account: account_ }) => account_ === account);
    if (!airdrop) return BigNumber.from(0);
    return airdrop.amount;
  }

  /**
   * @dev Get proofs for the leaf in a particular index
   * @param index Index of the leaf to get the proof
   */
  proofsFromIndex(index: number): string[] {
    return this.proofs(this.leaves[index]);
  }
}
