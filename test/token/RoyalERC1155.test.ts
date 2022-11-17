// RoyalERC1155.test.ts: Unit tests for RoyalERC1155 token

// Solidity extension for chai
import { solidity } from "ethereum-waffle";

// Use Chai for testing
import chai from "chai";
import { expect } from "chai";
// Setup chai plugins
chai.use(solidity);

// Import BigNumber utility functions
import { randomUint256, uint256 } from "../utils/bn_utils";
import { RoyalERC1155Mock, RoyalERC1155Mock__factory } from "../../typechain-types";

// HardhatRuntimeEnvironment
import { ethers } from "hardhat";

// Get BigNumber
import { BigNumber } from "@ethersproject/bignumber";
import { Signer } from "@ethersproject/abstract-signer";

describe.only("RoyalERC1155 Unit Tests", () => {
  let deployer: Signer;
  let admin: Signer;
  let owner: Signer;
  let user: Signer;
  let royalToken: RoyalERC1155Mock;

  const contractURI = "https://test.com/";

  before(async () => {
    // get signers
    [deployer, admin, owner, user] = await ethers.getSigners();
    // deploy royalToken contract
    const royalTokenFactory = <RoyalERC1155Mock__factory>await ethers.getContractFactory("RoyalERC1155Mock");
    royalToken = await royalTokenFactory.connect(deployer).deploy(contractURI, admin.getAddress(), owner.getAddress());
  });

  it("setAdmin: should revert with '!admin' if caller is not the admin", async () => {
    // should revert with "!admin" message
    await expect(royalToken.setAdmin(user.getAddress())).to.be.revertedWith("!admin");
  });

  it("setAdmin: should revert with 'admin == _admin' message when setting the same admin", async () => {
    // should revert with "admin == _admin" message
    await expect(royalToken.connect(admin).setAdmin(admin.getAddress())).to.be.revertedWith("admin == _admin");
  });

  it("isOwner: should return true if owner", async () => {
    // should return true
    expect(await royalToken.isOwner(await owner.getAddress())).to.be.equal(true);
  });

  describe("Check if admin is updated", () => {
    let newAdmin: Signer;

    before(async () => {
      [newAdmin] = (await ethers.getSigners()).slice(4);
    });
    it("setAdmin: should emit 'SetAdmin' on success", async () => {
      // set new admin
      const [newAdmin] = (await ethers.getSigners()).slice(4);
      // should emit "NewAdmin"
      await expect(royalToken.connect(admin).setAdmin(newAdmin.getAddress()))
        .to.emit(royalToken, "NewAdmin")
        .withArgs(await newAdmin.getAddress());
    });

    it("setAdmin: should revert with '!admin' if caller is not the admin", async () => {
      // should revert with "!admin" message
      await expect(royalToken.connect(admin).setAdmin(admin.getAddress())).to.be.revertedWith("!admin");

      // restore admin
      await royalToken.connect(newAdmin).setAdmin(await admin.getAddress());
    });
  });

  describe("Set the default royalties info (for all token IDs)", () => {
    let royaltyReceiver: Signer;

    const FEE_DENOMINATOR = BigNumber.from("8000");

    before(async () => {
      [royaltyReceiver] = (await ethers.getSigners()).slice(5);
    });

    it("setDefaultRoyalty: should revert if default value for setDefaultRoyalt is greater than allowed in contract", async () => {
      const feeDenominator = BigNumber.from("15000");
      // should revert with "ERC2981: royalty fee will exceed salePrice" message
      await expect(
        royalToken.connect(admin).setDefaultRoyalty(royaltyReceiver.getAddress(), feeDenominator),
      ).to.be.revertedWith("ERC2981: royalty fee will exceed salePrice");
    });

    it("setDefaultRoyalty: should revert if invalid address", async () => {
      const invalidAddress = "0x0000000000000000000000000000000000000000";
      // should revert with "ERC2981: invalid receiver" message
      await expect(royalToken.connect(admin).setDefaultRoyalty(invalidAddress, FEE_DENOMINATOR)).to.be.revertedWith(
        "ERC2981: invalid receiver",
      );
    });

    it("setDefaultRoyalty: should emit 'SetDefaultRoyalties' on success", async () => {
      // should emit "SetTokenRoyalty"
      await expect(royalToken.connect(admin).setDefaultRoyalty(royaltyReceiver.getAddress(), FEE_DENOMINATOR))
        .to.emit(royalToken, "SetDefaultRoyalties")
        .withArgs(await admin.getAddress(), await royaltyReceiver.getAddress(), FEE_DENOMINATOR);
    });
  });

  describe("Set royalties info for a specific token ID", () => {
    let royaltyReceiver: Signer;
    let contractFeeNumerator: BigNumber;

    const FEE_DENOMINATOR = BigNumber.from("8000");

    before(async () => {
      [royaltyReceiver] = (await ethers.getSigners()).slice(6);
      contractFeeNumerator = await royalToken.feeDenominator();
    });

    it("setTokenRoyalty: should revert if default value for setDefaultRoyalt is greater than allowed in contract", async () => {
      const feeDenominator = BigNumber.from("15000");
      // should revert with "ERC2981: royalty fee will exceed salePrice" message
      await expect(
        royalToken.connect(admin).setDefaultRoyalty(royaltyReceiver.getAddress(), feeDenominator),
      ).to.be.revertedWith("ERC2981: royalty fee will exceed salePrice");
    });

    it("setTokenRoyalty: should revert if invalid address", async () => {
      const invalidAddress = "0x0000000000000000000000000000000000000000";
      // should revert with "ERC2981: invalid receiver" message
      await expect(royalToken.connect(admin).setDefaultRoyalty(invalidAddress, FEE_DENOMINATOR)).to.be.revertedWith(
        "ERC2981: invalid receiver",
      );
    });

    // it("setTokenRoyalty: should emit 'SetDefaultRoyalties' on success", async () => {
    //   // should emit "SetTokenRoyalty"
    //   await expect(royalToken.connect(admin).setTokenRoyalty(royaltyReceiver.getAddress(), FEE_DENOMINATOR))
    //     .to.emit(royalToken, "SetTokenRoyalty")
    //     .withArgs(await admin.getAddress(), await royaltyReceiver.getAddress(), FEE_DENOMINATOR);
    // });
  });
});
