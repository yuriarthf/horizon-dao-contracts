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

  const maxSupply = addDecimalPoints(100000000);
  const numberOfEpochs = 5;
  const initialEpochStartOffset = 86400; // 1 day in seconds
  let firstEpochStartTime: number;
  const epochDurations = [oneMonth, 2 * oneMonth, 3 * oneMonth, 4 * oneMonth];
  const rampValues = Array(5).fill(maxSupply.div(5));

  function getAvailableSupply(epoch: number): BigNumber {
    if (epoch === 0) return BigNumber.from(0);
    return rampValues.slice(0, epoch).reduce((prev, curr) => prev.add(curr));
  }

  async function getMintableSupply(skyToken: SkyERC20, epoch: number): Promise<BigNumber> {
    return getAvailableSupply(epoch).sub(await skyToken.totalSupply());
  }

  before(async () => {
    // get deployer address
    [deployer, admin, burner, minter, user] = await ethers.getSigners();

    // get current block timestamp
    const currentBlockNumber = await ethers.provider.getBlockNumber();
    const currentBlock = await ethers.provider.getBlock(currentBlockNumber);

    // deploy skyERC20 contract
    firstEpochStartTime = currentBlock.timestamp + initialEpochStartOffset;
    const skyTokenFactory = <SkyERC20__factory>await ethers.getContractFactory("SkyERC20");
    skyToken = await skyTokenFactory
      .connect(deployer)
      .deploy(admin.getAddress(), numberOfEpochs, firstEpochStartTime, epochDurations, rampValues);

    // set burner and minter
    await skyToken.connect(admin).setBurner(burner.getAddress());
    await skyToken.connect(admin).setMinter(minter.getAddress());
  });

  describe("Before the first epoch begins", () => {
    it("Unlocked supply is zero", async () => {
      expect(await skyToken.availableSupply()).to.be.equal(BigNumber.from(0));
    });
    it("Mintable supply is zero", async () => {
      expect(await skyToken.mintableSupply()).to.be.equal(BigNumber.from(0));
    });
    it("Revert if trying to mint more than current available supply", async () => {
      // should revert with "Not enough available supply" message
      await expect(skyToken.connect(minter).mint(user.getAddress(), BigNumber.from(1))).to.be.revertedWith(
        "Not enough available supply",
      );
    });
  });
  describe("Epoch testing", () => {
    function epochTest(epoch: number) {
      before(async () => {
        // check if epoch is valid (epoch >= 1)
        if (epoch < 1) throw new Error("Invalid epoch");

        // get epoch start time
        let epochStartTime = firstEpochStartTime;
        if (epoch >= 2) {
          epochDurations.slice(0, epoch - 1).forEach((duration) => (epochStartTime += duration));
        }

        // set next block timestamp to first epoch
        await ethers.provider.send("evm_mine", [epochStartTime]);
      });
      it("Check unlocked supply correctness", async () => {
        // get available supply
        const availableSupply = getAvailableSupply(epoch);

        // assert value from contract
        expect(await skyToken.connect(minter).availableSupply()).to.be.equal(availableSupply);
      });
      it("Mint random amount of available tokens", async () => {
        // get mintable supply
        const mintableSupplyBefore = await getMintableSupply(skyToken, epoch);

        // check if contract returns the same value as JS impl
        expect(await skyToken.mintableSupply()).to.be.equal(mintableSupplyBefore);

        // amount to mint
        const amount = randomUint256().mod(mintableSupplyBefore);

        // get balance of user before
        const userBalanceBefore = await skyToken.balanceOf(user.getAddress());

        // mint tokens to user
        await skyToken.connect(minter).mint(user.getAddress(), amount);

        // check if user received the balance
        expect(await skyToken.balanceOf(user.getAddress())).to.be.equal(userBalanceBefore.add(amount));

        // check if mintable supply decreased by amount
        expect(await skyToken.mintableSupply()).to.be.equal(mintableSupplyBefore.sub(amount));
      });
      it("Revert if trying to mint more than current available supply", async () => {
        // get mintable supply
        const mintableSupply = await getMintableSupply(skyToken, epoch);

        // add surplus
        const randomBN = randomUint256();
        const randomNumberSurplus = randomBN.eq(BigNumber.from(0)) ? BigNumber.from(1) : randomBN;
        const amount = uint256(mintableSupply.add(randomNumberSurplus));

        // should revert with "Not enough available supply" message
        await expect(skyToken.connect(minter).mint(user.getAddress(), amount)).to.be.revertedWith(
          "Not enough available supply",
        );
      });
    }
    describe("First epoch begins", () => {
      epochTest(1);
    });
    describe("Second epoch begins", () => {
      epochTest(2);
    });
    describe("Third epoch begins", () => {
      epochTest(3);
    });
    describe("Forth epoch begins", () => {
      epochTest(4);
    });
    describe("Fifth epoch begins", () => {
      epochTest(5);
    });
  });
});
