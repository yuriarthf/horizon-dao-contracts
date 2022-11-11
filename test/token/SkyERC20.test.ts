// skyERC20.tests.ts: Unit tests for SkyERC20 token

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
import { randomUint256 } from "../utils/bn_utils";

describe("SkyERC20 Unit Tests", () => {
  let deployer: Signer;
  let skyToken: SkyERC20;
  let admin: Signer;
  let initialHolder: Signer;
  let minter: Signer;
  let user: Signer;
  let newAdmin: Signer;

  const MAX_SUPPLY = ethers.utils.parseEther("100000000");
  const INITIAL_SUPPLY = ethers.utils.parseEther("25000000");

  before(async () => {
    // get deployer address
    [deployer, admin, initialHolder, minter, user, newAdmin] = await ethers.getSigners();

    // deploy skyERC20 contract
    const skyTokenFactory = <SkyERC20__factory>await ethers.getContractFactory("SkyERC20");
    skyToken = await skyTokenFactory
      .connect(deployer)
      .deploy(admin.getAddress(), INITIAL_SUPPLY, initialHolder.getAddress());

    // set and minter
    await skyToken.connect(admin).setMinter(minter.getAddress());
  });

  it("constructor: reverts with 'MAX_SUPPLY' message if initial supply is greater than MAX_SUPPLY", async () => {
    // get constructor
    const skyTokenFactory = <SkyERC20__factory>await ethers.getContractFactory("SkyERC20");

    // should revert with "MAX_SUPPLY"
    await expect(
      skyTokenFactory.connect(deployer).deploy(admin.getAddress(), MAX_SUPPLY.add(1), initialHolder.getAddress()),
    ).to.be.revertedWith("MAX_SUPPLY");
  });

  it("Try to set roles with an account other than admin should revert", async () => {
    // set admin
    await expect(skyToken.connect(user).setAdmin(user.getAddress())).to.be.revertedWith("!admin");

    // set minter
    await expect(skyToken.connect(user).setMinter(user.getAddress())).to.be.revertedWith("!admin");
  });
  it("New admin and minter should have different addresses than the previous ones", async () => {
    // try setting new admin to the same address
    await expect(skyToken.connect(admin).setAdmin(admin.getAddress())).to.be.revertedWith("Same admin");

    // try setting new minter to the same address
    await expect(skyToken.connect(admin).setMinter(minter.getAddress())).to.be.revertedWith("Same minter");
  });
  it("Change admin and minter should emit events", async () => {
    // change to a new admin
    await expect(skyToken.connect(admin).setAdmin(newAdmin.getAddress()))
      .to.emit(skyToken, "SetAdmin")
      .withArgs(await admin.getAddress(), await newAdmin.getAddress());

    // change to a new minter
    await expect(skyToken.connect(newAdmin).setMinter(newAdmin.getAddress()))
      .to.emit(skyToken, "SetMinter")
      .withArgs(await newAdmin.getAddress(), await newAdmin.getAddress());

    // give the roles back to the previous owners
    await skyToken.connect(newAdmin).setAdmin(admin.getAddress());
    await skyToken.connect(admin).setMinter(minter.getAddress());
  });

  describe("Mint tokens", () => {
    const MAX_ITERATIONS = 500;

    it("mint: reverts with '!minter' if caller is not the minter", async () => {
      // amount to mint
      const amountToMint = randomUint256()
        .mod(await skyToken.mintableSupply())
        .add(1);

      // should revert with "!minter" message
      await expect(skyToken.mint(user.getAddress(), amountToMint)).to.revertedWith("!minter");
    });

    it("mint: reverts with 'MAX_SUPPLY' when trying to surpass MAX_SUPPLY", async () => {
      // get mintable supply
      const mintableSupply = await skyToken.mintableSupply();

      // should revert with "MAX_SUPPLY"
      await expect(skyToken.connect(minter).mint(user.getAddress(), mintableSupply.add(1))).to.be.revertedWith(
        "MAX_SUPPLY",
      );
    });

    it("mint: should emit 'Mint' event and update user balance", async () => {
      // get amount to mint
      let amountToMint;
      let mintableSupply = await skyToken.mintableSupply();
      let userBalanceBefore = await skyToken.balanceOf(user.getAddress());
      let userBalanceAfter: BigNumber;
      let iteration = 0;
      do {
        amountToMint = randomUint256().mod(mintableSupply).add(1);

        // should emit "Mint" event
        await expect(skyToken.connect(minter).mint(user.getAddress(), amountToMint))
          .to.emit(skyToken, "Mint")
          .withArgs(await minter.getAddress(), await user.getAddress(), amountToMint);
        mintableSupply = await skyToken.mintableSupply();

        // check user balance
        userBalanceAfter = await skyToken.balanceOf(user.getAddress());
        expect(userBalanceAfter.sub(userBalanceBefore)).to.be.equal(amountToMint);
        userBalanceBefore = userBalanceAfter;
      } while (iteration++ < MAX_ITERATIONS && !mintableSupply.isZero());
    });
  });
});
