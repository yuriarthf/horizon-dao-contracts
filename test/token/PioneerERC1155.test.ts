// PioneerERC1155.test.ts: Unit tests for SkyERC20 token

// Solidity extension for chai
import { solidity } from "ethereum-waffle";

// Use Chai for testing
import chai from "chai";
import { expect } from "chai";
// Setup chai plugins
chai.use(solidity);

// Import contract types
import type { PioneerERC1155, PioneerERC1155__factory } from "../../typechain-types";

// HardhatRuntimeEnvironment
import { ethers } from "hardhat";

// Get BigNumber
import { BigNumber, BigNumberish } from "@ethersproject/bignumber";
import { Signer } from "@ethersproject/abstract-signer";

// Import BigNumber utility functions
import { randomUint256, uint256 } from "../utils/bn_utils";

// Import merkle tree constructors
import { PioneerTree, AirdropTree } from "./utils/pioneer_tree";

describe("PioneerERC1155 Unit Tests", () => {
  let deployer: Signer;
  let admin: Signer;
  let owner: Signer;
  let user: Signer;
  let pioneerToken: PioneerERC1155;

  const IMAGE_URI = "https://test.com/";
  const PUBLIC_TOKEN_UNIT_PRICE = ethers.utils.parseEther("0.15");
  const WHITELIST_TOKEN_UNIT_PRICE = ethers.utils.parseEther("0.1");
  const CHANCES = [948, 47, 5].map((chance) => BigNumber.from(chance));

  enum Pioneer {
    BRONZE,
    SILVER,
    GOLD,
  }

  function collectionName(id: Pioneer) {
    switch (id) {
      case Pioneer.BRONZE:
        return "Bronze Horizon Pioneer Badge";
      case Pioneer.SILVER:
        return "Silver Horizon Pioneer Badge";
      case Pioneer.GOLD:
        return "Gold Horizon Pioneer Badge";
      default:
        throw new Error("Invalid id");
    }
  }

  function collectionDescription(id: Pioneer) {
    switch (id) {
      case Pioneer.BRONZE:
        return "";
      case Pioneer.SILVER:
        return "";
      case Pioneer.GOLD:
        return "";
      default:
        throw new Error("Invalid id");
    }
  }

  function collectionMetadata(id: Pioneer) {
    return JSON.stringify({
      name: collectionName(id),
      description: collectionDescription(id),
      image: IMAGE_URI + id.toString(),
    });
  }

  function uri(id: Pioneer) {
    return `data:application/json;base64,${Buffer.from(collectionMetadata(id)).toString("base64")}`;
  }

  before(async () => {
    // get deployer address
    [deployer, admin, owner, user] = await ethers.getSigners();

    // deploy skyERC20 contract
    const pioneerTokenFactory = <PioneerERC1155__factory>await ethers.getContractFactory("PioneerERC1155");
    pioneerToken = await pioneerTokenFactory
      .connect(deployer)
      .deploy(IMAGE_URI, admin.getAddress(), owner.getAddress(), PUBLIC_TOKEN_UNIT_PRICE, WHITELIST_TOKEN_UNIT_PRICE, [
        CHANCES[0],
        CHANCES[1],
        CHANCES[2],
      ]);
  });

  describe("Constructor", () => {
    let pioneerTokenFactory: PioneerERC1155__factory;

    before(async () => {
      // get SkyERC20 factory
      pioneerTokenFactory = <PioneerERC1155__factory>await ethers.getContractFactory("PioneerERC1155");
    });

    it("Reverts when _admin is ZERO_ADDRESS", async () => {
      // get deploy transaction
      const deployTransaction = pioneerTokenFactory
        .connect(deployer)
        .deploy(
          IMAGE_URI,
          ethers.constants.AddressZero,
          owner.getAddress(),
          PUBLIC_TOKEN_UNIT_PRICE,
          WHITELIST_TOKEN_UNIT_PRICE,
          [CHANCES[0], CHANCES[1], CHANCES[2]],
        );

      // Should revert with "Admin should not be ZERO ADDRESS" message
      await expect(deployTransaction).to.be.revertedWith("Admin should not be ZERO ADDRESS");
    });

    it("Reverts when _whitelistTokenUnitPrice >= _publicTokenUnitPrice", async () => {
      // get a random increment
      const randomIncrement = randomUint256();

      // get deploy transaction
      const deployTransaction = pioneerTokenFactory
        .connect(deployer)
        .deploy(
          IMAGE_URI,
          admin.getAddress(),
          owner.getAddress(),
          PUBLIC_TOKEN_UNIT_PRICE,
          PUBLIC_TOKEN_UNIT_PRICE.add(randomIncrement),
          [CHANCES[0], CHANCES[1], CHANCES[2]],
        );

      // Should revert with "No discount applied" message
      await expect(deployTransaction).to.be.revertedWith("No discount applied");
    });

    it("Revert if chances doesn't add up to MAX_CHANCE", async () => {
      // get deploy transaction
      const deployTransaction = pioneerTokenFactory
        .connect(deployer)
        .deploy(
          IMAGE_URI,
          admin.getAddress(),
          owner.getAddress(),
          PUBLIC_TOKEN_UNIT_PRICE,
          WHITELIST_TOKEN_UNIT_PRICE,
          [CHANCES[0], CHANCES[1], CHANCES[2].add(1)],
        );

      // Should revert with "No discount applied" message
      await expect(deployTransaction).to.be.revertedWith("_chances sum should be MAX_CHANCE");
    });
  });

  it("Check imageURI", async () => {
    // iterate over all pioneerNFT types and compare the imageUri
    let imageUri: string;
    for (let id = Pioneer.BRONZE; id <= Pioneer.GOLD; id++) {
      imageUri = await pioneerToken.imageURI(id);
      expect(imageUri).to.be.equal(IMAGE_URI + id.toString());
    }
  });

  it("Check collectionName", async () => {
    // iterate over all pioneerNFT types and compare the collection names
    for (let id = Pioneer.BRONZE; id <= Pioneer.GOLD; id++) {
      expect(await pioneerToken.collectionName(id)).to.be.equal(collectionName(id));
    }
  });

  it("Check collectionDescription", async () => {
    // iterate over all pioneerNFT types and compare the collection descriptions
    for (let id = Pioneer.BRONZE; id <= Pioneer.GOLD; id++) {
      expect(await pioneerToken.collectionDescription(id)).to.be.equal(collectionDescription(id));
    }
  });

  it("Check collectionMetadata", async () => {
    // iterate over all pioneerNFT types and compare the collection metadata
    for (let id = Pioneer.BRONZE; id <= Pioneer.GOLD; id++) {
      expect(await pioneerToken.collectionMetadata(id)).to.be.equal(collectionMetadata(id));
    }
  });

  it("Check uri", async () => {
    // iterate over all pioneerNFT types and compare the collection's uri
    for (let id = Pioneer.BRONZE; id <= Pioneer.GOLD; id++) {
      expect(await pioneerToken.uri(id)).to.be.equal(uri(id));
    }
  });

  it("Make sure saleInitialized return false before Sale is initialized", async () => {
    // saleInitialized should return false
    expect(await pioneerToken.saleInitialized()).to.be.false;
  });

  describe("Private claiming", () => {
    let privateSigner1: Signer;
    let privateSigner2: Signer;
    let privateSigner3: Signer;
    let privateSigner4: Signer;
    let privateWhitelistTree: PioneerTree;

    before(async () => {
      // get private whitelist signers
      [privateSigner1, privateSigner2, privateSigner3, privateSigner4] = await ethers.getSigners();

      // build private whitelist tree
      privateWhitelistTree = new PioneerTree([
        await privateSigner1.getAddress(),
        await privateSigner2.getAddress(),
        await privateSigner3.getAddress(),
        await privateSigner4.getAddress(),
      ]);
    });

    it("setPrivateRoot: revert if caller is not admin", async () => {
      // Should revert with "!admin" message
      await expect(pioneerToken.setPrivateRoot(privateWhitelistTree.root)).to.be.revertedWith("!admin");
    });

    it("setPrivateRoot: should emit 'PrivateMerkleRootSet' event when successful", async () => {
      // Should emit "PrivateMerkleRootSet" event
      await expect(pioneerToken.connect(admin).setPrivateRoot(privateWhitelistTree.root))
        .to.emit(pioneerToken, "PrivateMerkleRootSet")
        .withArgs(await admin.getAddress(), privateWhitelistTree.root);
    });

    it("privateClaim: successful claims", async () => {
      // Private whitelisted signers array
      const privateSigners = [privateSigner1, privateSigner2, privateSigner3, privateSigner4];

      // claim tokens
      for (let i = 0; i < privateSigners.length; i++) {
        await expect(pioneerToken.connect(privateSigners[i]).privateClaim(privateWhitelistTree.proofsFromIndex(i)))
          .to.emit(pioneerToken, "PioneerClaimed")
          .withArgs(await privateSigners[i].getAddress(), Pioneer.GOLD, false, 1);
        expect(await pioneerToken.userPrivateClaimed(privateSigners[i].getAddress())).to.be.true;
        expect(await pioneerToken.balanceOf(privateSigners[i].getAddress(), Pioneer.GOLD)).to.be.equal(
          BigNumber.from(1),
        );
      }
    });

    it("privateClaim: trying to claim again should revert", async () => {
      // should revert with "claimed" message
      await expect(
        pioneerToken.connect(privateSigner1).privateClaim(privateWhitelistTree.proofsFromIndex(0)),
      ).to.be.revertedWith("claimed");
    });

    it("privateClaim: claiming with a non-whitelisted address should revert", async () => {
      // should revert with "!root" message
      await expect(pioneerToken.connect(user).privateClaim(privateWhitelistTree.proofsFromIndex(0))).to.be.revertedWith(
        "!root",
      );
    });
  });
});
