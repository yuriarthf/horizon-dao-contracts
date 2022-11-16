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

describe("RoyalERC1155 Unit Tests", () => {
  let deployer: Signer;
  let admin: Signer;
  let owner: Signer;
  let royalToken: RoyalERC1155Mock;

  const contractURI = "https://test.com/";

  before(async () => {
    // get deployer address
    [deployer, admin, owner] = await ethers.getSigners();
    console.log("deployer address: ", await deployer.getAddress());
    console.log("admin address: ", await admin.getAddress());
    console.log("owner address: ", await owner.getAddress());

    // deploy royalToken contract
    const royalTokenFactory = <RoyalERC1155Mock__factory>await ethers.getContractFactory("RoyalERC1155Mock");
    royalToken = await royalTokenFactory.connect(deployer).deploy(contractURI, admin.getAddress(), owner.getAddress());
  });

  it("setAdmin: should emit 'SetAdmin' on success", async () => {
    const [newAdmin] = (await ethers.getSigners()).slice(3);
    console.log("newAdmin address: ", await newAdmin.getAddress());
    // should emit "NewAdmin"
    await expect(royalToken.connect(admin).setAdmin(newAdmin.getAddress()))
      .to.emit(royalToken, "NewAdmin")
      .withArgs(await newAdmin.getAddress());
  });

  it("setAdmin: should revert with 'admin == _admin' message when setting the same admin", async () => {
    // should revert with "admin == _admin" message
    await expect(royalToken.connect(admin).setAdmin(admin.getAddress())).to.be.revertedWith("admin == _admin");
  });

  it("isOwner: should return true if owner", async () => {
    // should return true
    expect(await royalToken.isOwner(await owner.getAddress())).to.be.equal(true);
  });

  it("setDefaultRoyalty: should revert / validate / return ?? ", async () => {
    const [receiver] = (await ethers.getSigners()).slice(4);
    const FEE_NUMERATOR = BigNumber.from("10");

    // should revert / validate / return ??
    // await expect(royalToken.setDefaultRoyalty(uint256(100))).to.be.revertedWith("!admin");
  });

  it("setTokenRoyalty: should revert / validate / return ?? ", async () => {
    // should revert / validate / return ??
    // await expect(royalToken.setTokenRoyalty(uint256(100))).to.be.revertedWith("!admin");
  });
});
