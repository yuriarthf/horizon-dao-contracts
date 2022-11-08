// RealEstateERC1155.test.ts: Unit tests for RealEstateERC1155 token

// Solidity extension for chai
import { solidity } from "ethereum-waffle";

// Use Chai for testing
import chai from "chai";
import { expect } from "chai";
// Setup chai plugins
chai.use(solidity);

// Import contract types
import type { RealEstateERC1155, RealEstateERC1155__factory, SingleApprovableERC1155 } from "../../typechain-types";

// HardhatRuntimeEnvironment
import { ethers } from "hardhat";

// Get BigNumber
import { BigNumber, BigNumberish } from "@ethersproject/bignumber";
import { Wallet } from "@ethersproject/wallet";
import { Signer } from "@ethersproject/abstract-signer";

// Import BigNumber utility functions
import { randomUint256 } from "../utils/bn_utils";

// Import EVM utils
import { setBlockTimestamp, setAccountBalance } from "../utils/evm_utils";

describe("RealEstateERC1155 Unit Tests", () => {
  let deployer: Signer;
  let admin: Signer;
  let owner: Signer;
  let minter: Signer;
  let burner: Signer;
  let realEstateToken: RealEstateERC1155;

  const BASE_URI = "https://test.com/";
  const NAME = "Real Estate NFT";
  const SYMBOL = "reNFT";

  before(async () => {
    // get signers
    [deployer, admin, owner, minter, burner] = await ethers.getSigners();

    // deploy RealEstateERC1155 contract
    const realEstateTokenFactory = <RealEstateERC1155__factory>await ethers.getContractFactory("RealEstateERC1155");
    realEstateToken = await realEstateTokenFactory
      .connect(deployer)
      .deploy(BASE_URI, admin.getAddress(), owner.getAddress());
  });

  it("name: should be equal to NAME", async () => {
    // check RealEstateERC1155 name
    expect(await realEstateToken.name()).to.be.equal(NAME);
  });

  it("symbol: should be equal to SYMBOL", async () => {
    // heck RealEstateERC1155 symbol
    expect(await realEstateToken.symbol()).to.be.equal(SYMBOL);
  });

  it("setMinter: should emit 'SetMinter' on success", async () => {
    // should emit "SetMinter"
    await expect(realEstateToken.connect(admin).setMinter(minter.getAddress()))
      .to.emit(realEstateToken, "SetMinter")
      .withArgs(await admin.getAddress(), await minter.getAddress());
  });

  it("setMinter: should revert with 'Same minter' message when setting the same minter", async () => {
    // should revert with "Same minter" message
    await expect(realEstateToken.connect(admin).setMinter(minter.getAddress())).to.be.revertedWith("Same minter");
  });

  it("setBurner: should emit 'SetBurner' on success", async () => {
    // should emit "SetBurner"
    await expect(realEstateToken.connect(admin).setBurner(burner.getAddress()))
      .to.emit(realEstateToken, "SetBurner")
      .withArgs(await admin.getAddress(), await burner.getAddress());
  });

  it("setBurner: should revert with 'Same burner' message when setting the same burner", async () => {
    // should revert with "Same burner" message
    await expect(realEstateToken.connect(admin).setBurner(burner.getAddress())).to.be.revertedWith("Same burner");
  });

  describe("Mint event", () => {
    const FIRST_MINT = BigNumber.from("1000");
    const ADDITIONAL_FIRST_MINT = BigNumber.from("500");
    const SECOND_MINT = BigNumber.from("2000");

    let currentId = BigNumber.from("0");
  });
});
