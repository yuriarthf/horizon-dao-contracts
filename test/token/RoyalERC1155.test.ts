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

    // deploy royalToken contract
    const royalTokenFactory = <RoyalERC1155Mock__factory>await ethers.getContractFactory("RoyalERC1155Mock");
    royalToken = await royalTokenFactory.connect(deployer).deploy(contractURI, admin.getAddress(), owner.getAddress());
  });

  it("setAdmin: should emit 'SetAdmin' on success", async () => {
    const [newAdmin] = await ethers.getSigners();
    // should emit "NewAdmin"
    await expect(royalToken.connect(admin).setAdmin(newAdmin.getAddress()))
      .to.emit(royalToken, "NewAdmin")
      .withArgs(await admin.getAddress(), await newAdmin.getAddress());
  });
});
