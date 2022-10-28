// citizenship_tree.ts: Implements CitizenshipTree class to be used to
// generate merkle roots to be set for the CitizenshipPromoERC1155 contract

// Import MerkleTree class to build the citizenship merkle tree
import { MerkleTree } from "merkletreejs";

// Ethers for keccak256 hash
import ethers from "ethers";

// Import types
import type { Address, Airdrop } from "../../types";

/**
 * @dev Used to get the whitelisted citizenships merkle roots (private claim and whitelist sale),
 *      to be set in the CitizenshipERC1155 contract.
 */
export class CitizenshipTree {
  readonly citizenshipTree: MerkleTree;
  readonly accounts: Address[];

  /**
   * @dev Build citizenship merkle tree
   * @param accounts Whitelisted accounts
   */
  constructor(accounts: Address[]) {
    this.accounts = accounts;
    const leaves = accounts.map((address) => ethers.utils.keccak256(address));
    this.citizenshipTree = new MerkleTree(leaves, ethers.utils.keccak256);
  }

  /**
   * @dev Get citizenship merkle tree leaves (whitelisted addresses)
   */
  get leaves() {
    return this.accounts.map((address) => ethers.utils.keccak256(address));
  }

  /**
   * @dev Get citizenship merkle tree root
   */
  get root() {
    return this.citizenshipTree.getHexRoot();
  }

  /**
   * @dev Get merkle proofs for a given leaf
   * @param leaf Keccak256 hash of a citizenship merkle tree account
   */
  proofs(leaf: string): string[] {
    return this.citizenshipTree.getHexProof(leaf);
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
    const leaves = airdrops.map((airdrop) =>
      ethers.utils.keccak256(ethers.utils.solidityPack(["address", "uint256"], [airdrop.account, airdrop.amount])),
    );
    this.airdropTree = new MerkleTree(leaves, ethers.utils.keccak256);
  }

  /**
   * @dev Get citizenship merkle tree leaves (whitelisted addresses)
   */
  get leaves() {
    return this.airdrops.map((airdrop) =>
      ethers.utils.keccak256(ethers.utils.solidityPack(["address", "uint256"], [airdrop.account, airdrop.amount])),
    );
  }

  /**
   * @dev Get citizenship merkle tree root
   */
  get root() {
    return this.airdropTree.getHexRoot();
  }

  /**
   * @dev Get merkle proofs for a given leaf
   * @param leaf Keccak256 hash of a citizenship merkle tree account
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
