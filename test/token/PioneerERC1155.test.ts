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
});
