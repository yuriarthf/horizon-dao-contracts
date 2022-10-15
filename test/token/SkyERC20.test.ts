// skyERC20.ts: Unit tests for SkyERC20 token

// Solidity extension for chai
import { solidity } from "ethereum-waffle";

// Use Chai for testing
import chai from "chai";
import { expect } from "chai";
// Setup chai plugins
chai.use(solidity);

// Import contract types
import type { SkyERC20, SkyERC20__factory } from "../../typechain-types";

// HardhatRuntimeEnvironment
import { ethers } from "hardhat";

// Get BigNumber
import { BigNumber } from "@ethersproject/bignumber";
import { Signer } from "@ethersproject/abstract-signer";

// Import BigNumber utility functions
import { randomUint256, uint256 } from "../utils/bn_utils";

describe("SkyERC20 Unit Tests", () => {
  let deployer: Signer;
  let skyToken: SkyERC20;
  let admin: Signer;
  let burner: Signer;
  let minter: Signer;
  let user: Signer;

  function addDecimalPoints(num: number, decimals = 18): BigNumber {
    return BigNumber.from(num).mul(BigNumber.from(10).pow(decimals));
  }

  const oneMonth = 2630000; // 1 month in seconds

  const maxSupply = addDecimalPoints(200000000);
  const numberOfEpochs = 5;
  const initialEpochStartOffset = 86400; // 1 day in seconds
  let initialEpochStart: number;
  const epochDurations = [oneMonth, 2 * oneMonth, 3 * oneMonth, 4 * oneMonth];
  const rampValues = Array(5).fill(maxSupply.div(5));

  function getUnlockedSupply(epoch: number): BigNumber {
    if (epoch === 0) return BigNumber.from(0);
    return rampValues.slice(0, epoch).reduce((prev, curr) => prev.add(curr));
  }

  async function getMintableSupply(skyToken: SkyERC20, epoch: number): Promise<BigNumber> {
    return getUnlockedSupply(epoch).sub(await skyToken.totalSupply());
  }

  before(async () => {
    // get deployer address
    [deployer, admin, burner, minter, user] = await ethers.getSigners();

    // get current block timestamp
    const currentBlockNumber = await ethers.provider.getBlockNumber();
    const currentBlock = await ethers.provider.getBlock(currentBlockNumber);

    // deploy skyERC20 contract
    initialEpochStart = currentBlock.timestamp + initialEpochStartOffset;
    const skyTokenFactory = <SkyERC20__factory>await ethers.getContractFactory("SkyERC20");
    skyToken = await skyTokenFactory
      .connect(deployer)
      .deploy(admin.getAddress(), numberOfEpochs, initialEpochStart, epochDurations, rampValues);

    // set burner and minter
    await skyToken.connect(admin).setBurner(burner.getAddress());
    await skyToken.connect(admin).setMinter(minter.getAddress());
  });

  describe("Before the first epoch begins", () => {
    it("Unlocked supply is zero", async () => {
      expect(await skyToken.getUnlockedSupply()).to.be.equal(BigNumber.from(0));
    });
    it("Mintable supply is zero", async () => {
      expect(await skyToken.getMintableSupply()).to.be.equal(BigNumber.from(0));
    });
    it("Revert if trying to mint more than current available supply", async () => {
      // should revert with "Not enough available supply" message
      await expect(skyToken.connect(minter).mint(user.getAddress(), BigNumber.from(1))).to.be.revertedWith(
        "Not enough available supply",
      );
    });
  });
  describe("First epoch begins", () => {
    before(async () => {
      // set next block timestamp to first epoch
      await ethers.provider.send("evm_mine", [initialEpochStart]);
    });
    it("Check unlocked supply correctness", async () => {
      // get unlocked supply
      const unlockedSupply = getUnlockedSupply(1);

      // assert value from contract
      expect(await skyToken.connect(minter).getUnlockedSupply()).to.be.equal(unlockedSupply);
    });
    it("Revert if trying to mint more than current available supply", async () => {
      // get mintable supply
      const mintableSupply = await getMintableSupply(skyToken, 1);

      // add surplus
      const randomBN = randomUint256();
      const randomNumberSurplus = randomBN.eq(BigNumber.from(0)) ? BigNumber.from(1) : randomBN;
      const amount = uint256(mintableSupply.add(randomNumberSurplus));

      // should revert with "Not enough available supply" message
      await expect(skyToken.connect(minter).mint(user.getAddress(), amount)).to.be.revertedWith(
        "Not enough available supply",
      );
    });
  });
});
