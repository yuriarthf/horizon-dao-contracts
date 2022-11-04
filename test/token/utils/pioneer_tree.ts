// pioneer_tree.ts: Implements PioneerTree and AirdropTree classes to be used to
// generate merkle roots to be set for the PioneerERC1155 contract

// Import MerkleTree class to build the pioneer merkle tree
import { MerkleTree } from "merkletreejs";

// Ethers for keccak256 hash
import { ethers } from "ethers";

// Import types
import type { Address, Airdrop } from "../../types";

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
        ethers.utils.keccak256(
          ethers.utils.solidityPack(["address", "uint256"], [airdrop.account, airdrop.amount]).substring(2),
        ),
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
   * @dev Get merkle proofs for a given leaf
   * @param leaf Keccak256 hash of a airdrop merkle tree account
   */
  proofs(leaf: string): string[] {
    return this.airdropTree.getHexProof(leaf);
  }

  /**
   * @dev Get proofs for the leaf in a particular index
   * @param index Index of the leaf to get the proof
   */
  proofsFromIndex(index: number): string[] {
    return this.proofs(this.leaves[index]);
  }
}
