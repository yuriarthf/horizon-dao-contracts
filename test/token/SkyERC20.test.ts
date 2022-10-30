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
  let minter: Signer;
  let user: Signer;
  let newAdmin: Signer;

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
    [deployer, admin, minter, user, newAdmin] = await ethers.getSigners();

    // get current block timestamp
    const currentBlockNumber = await ethers.provider.getBlockNumber();
    const currentBlock = await ethers.provider.getBlock(currentBlockNumber);

    // deploy skyERC20 contract
    firstEpochStartTime = currentBlock.timestamp + initialEpochStartOffset;
    const skyTokenFactory = <SkyERC20__factory>await ethers.getContractFactory("SkyERC20");
    skyToken = await skyTokenFactory
      .connect(deployer)
      .deploy(admin.getAddress(), numberOfEpochs, firstEpochStartTime, epochDurations, rampValues);

    // set and minter
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
        "amount > mintableSupply",
      );
    });
    it("Supply release shouldn't have started", async () => {
      // check contract flag
      expect(await skyToken.supplyReleaseStarted()).to.be.false;
    });

    it("Try to set roles with an account other than admin should revert", async () => {
      // set admin
      await expect(skyToken.connect(user).setAdmin(user.getAddress())).to.be.revertedWith("!admin");

      // set minter
      await expect(skyToken.connect(user).setMinter(user.getAddress())).to.be.revertedWith("!admin");
    });
    it("New admin and minter should have different addresses than the previous ones", async () => {
      // try setting new admin to the same address
      await expect(skyToken.connect(admin).setAdmin(admin.getAddress())).to.be.revertedWith("admin == _admin");

      // try setting new minter to the same address
      await expect(skyToken.connect(admin).setMinter(minter.getAddress())).to.be.revertedWith("minter == _minter");
    });
    it("Change admin and minter should emit events", async () => {
      // change to a new admin
      await expect(skyToken.connect(admin).setAdmin(newAdmin.getAddress()))
        .to.emit(skyToken, "NewAdmin")
        .withArgs(await newAdmin.getAddress());

      // change to a new minter
      await expect(skyToken.connect(newAdmin).setMinter(newAdmin.getAddress()))
        .to.emit(skyToken, "NewMinter")
        .withArgs(await newAdmin.getAddress());

      // give the roles back to the previous owners
      await skyToken.connect(newAdmin).setAdmin(admin.getAddress());
      await skyToken.connect(admin).setMinter(minter.getAddress());
    });
  });
  describe("Epoch testing", () => {
    let epochStartTime: number;
    function epochTest(epoch: number) {
      before(async () => {
        // check if epoch is valid (epoch >= 1)
        if (epoch < 1) throw new Error("Invalid epoch");

        // get epoch start time
        epochStartTime = firstEpochStartTime;
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
      it("Check other epoch metadata", async () => {
        // get epoch number
        const epochNumber = await skyToken.currentEpoch();

        // sanity check
        expect(epoch).to.be.equal(epochNumber);

        // get current epoch start time
        const currentEpochStartTime = await skyToken.currentEpochStartTime();

        // sanity check
        expect(epochStartTime).to.be.equal(currentEpochStartTime);

        // check if supply release started
        expect(await skyToken.supplyReleaseStarted()).to.be.true;
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

        // try to mint with user -- should revert
        await expect(skyToken.mint(user.getAddress(), amount)).to.be.revertedWith("!minter");

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
          "amount > mintableSupply",
        );
      });
    }

    [...Array(numberOfEpochs).keys()].forEach((value) => {
      describe(`Epoch ${value + 1} test`, () => {
        epochTest(value + 1);
      });
    });

    describe("Test constructor args requirements", () => {
      let skyTokenFactory: SkyERC20__factory;
      before(async () => {
        // get SkyERC20 factory
        skyTokenFactory = <SkyERC20__factory>await ethers.getContractFactory("SkyERC20");
      });
      it("Number of epochs should be greater than zero", async () => {
        // Revert with reason string: "_numberOfEpochs == 0"
        await expect(
          skyTokenFactory
            .connect(deployer)
            .deploy(admin.getAddress(), 0, firstEpochStartTime, epochDurations, rampValues),
        ).to.be.revertedWith("_numberOfEpochs == 0");
      });
      it("Ramp values length should be equal to number of epochs", async () => {
        // get invalid ramp values
        const invalidRampValues = [...rampValues.slice(0, rampValues.length - 1)];

        // Revert with reason string: "_rampValues.length != _numberOfEpochs"
        await expect(
          skyTokenFactory
            .connect(deployer)
            .deploy(admin.getAddress(), numberOfEpochs, firstEpochStartTime, epochDurations, invalidRampValues),
        ).to.be.revertedWith("_rampValues.length != _numberOfEpochs");
      });
      it("Epoch durations should only be provided for n - 1 epochs", async () => {
        // get invalid epoch durations
        const invalidEpochDurations = [...epochDurations, 10];

        // Revert with reason string: "_epochDurations.length != _numberOfEpochs-1"
        await expect(
          skyTokenFactory
            .connect(deployer)
            .deploy(admin.getAddress(), numberOfEpochs, firstEpochStartTime, invalidEpochDurations, rampValues),
        ).to.be.revertedWith("_epochDurations.length != _numberOfEpochs-1");
      });

      it("Sum of ramp values should be equal to MAX_SUPPLY", async () => {
        // get invalid ramp values
        const invalidRampValues = [...rampValues];
        invalidRampValues[numberOfEpochs - 1] = invalidRampValues[numberOfEpochs - 1].add(1);

        // Revert with reason string: "totalReleasedSupply != MAX_SUPPLY"
        await expect(
          skyTokenFactory
            .connect(deployer)
            .deploy(admin.getAddress(), numberOfEpochs, firstEpochStartTime, epochDurations, invalidRampValues),
        ).to.be.revertedWith("totalReleasedSupply != MAX_SUPPLY");
      });
    });
  });
});
