// pioneer_tree.ts: Implements PioneerTree class to be used to
// generate merkle roots to be set for the PioneerERC1155 contract

// Import MerkleTree class to build the pioneer merkle tree
import { MerkleTree } from "merkletreejs";

// Ethers for keccak256 hash
import { ethers } from "ethers";

// Import types
import type { Address } from "../../types";

/**
 * @dev Used to get the whitelisted merkle roots (private claim and whitelist sale),
 *      to be set in the PioneerERC1155 contract.
 */
export class PioneerTree {
  readonly pioneerTree: MerkleTree;
  readonly accounts: Address[];

  /**
   * @dev Build pioneer merkle tree
   * @param accounts Whitelisted accounts
   */
  constructor(accounts: Address[]) {
    this.accounts = accounts;
    this.pioneerTree = new MerkleTree(this.leaves, ethers.utils.keccak256, { sortPairs: true });
  }

  /**
   * @dev Get pioneer merkle tree leaves (whitelisted addresses)
   */
  get leaves() {
    return this.accounts.map((address) =>
      Buffer.from(ethers.utils.solidityKeccak256(["address"], [address]).substring(2), "hex"),
    );
  }

  /**
   * @dev Get pioneer merkle tree root
   */
  get root() {
    return this.pioneerTree.getHexRoot();
  }

  /**
   * @dev Get merkle proofs for a given leaf
   * @param leaf Keccak256 hash of a pioneer merkle tree account
   */
  proofs(leaf: Buffer): string[] {
    return this.pioneerTree.getHexProof(leaf);
  }

  /**
   * @dev Get proofs for the leaf in a particular index
   * @param index Index of the leaf to get the proof
   */
  proofsFromIndex(index: number): string[] {
    return this.proofs(this.leaves[index]);
  }
}
