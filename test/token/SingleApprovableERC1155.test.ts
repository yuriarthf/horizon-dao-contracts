// RoyalERC1155.test.ts: Unit tests for RoyalERC1155 token

// Solidity extension for chai
import { solidity } from "ethereum-waffle";

// Use Chai for testing
import chai from "chai";
import { expect } from "chai";
// Setup chai plugins
chai.use(solidity);

// Import contract mocks
import { SingleApprovableERC1155Mock, SingleApprovableERC1155Mock__factory } from "../../typechain-types";

// HardhatRuntimeEnvironment
import { ethers } from "hardhat";

// Get BigNumber
import { BigNumber } from "@ethersproject/bignumber";
import { Signer } from "@ethersproject/abstract-signer";

describe("SingleApprovableERC1155 Unit Tests", () => {
  let admin: Signer;
  let singleApprovableToken: SingleApprovableERC1155Mock;

  const CONTRACT_URI = "https://test.com/";

  before(async () => {
    // get signers
    [, admin] = await ethers.getSigners();

    // deploy royalToken contract
    const singleApprovableFactory = <SingleApprovableERC1155Mock__factory>(
      await ethers.getContractFactory("SingleApprovableERC1155Mock")
    );

    singleApprovableToken = await singleApprovableFactory.deploy(CONTRACT_URI);
    await singleApprovableToken.deployed();
  });

  describe("Approval", () => {
    let user: Signer;
    let tokenId: BigNumber;
    let amount: BigNumber;

    before(async () => {
      [user] = (await ethers.getSigners()).slice(3);
      tokenId = BigNumber.from(1);
      amount = BigNumber.from(100);
    });

    it("approve: should revert with 'Approve from the zero address'", async () => {
      // set sender to zero address
      await singleApprovableToken.connect(user).toggleMsgSenderMock(true);

      // should revert with "!admin" message
      await expect(singleApprovableToken.connect(user).approve(tokenId, admin.getAddress(), amount)).to.be.revertedWith(
        "Approve from the zero address",
      );

      // restore default sender
      await singleApprovableToken.connect(user).toggleMsgSenderMock(false);
    });

    it("approve: should revert with 'Approve to the zero address'", async () => {
      // should revert with "Approve to the zero address" message
      await expect(
        singleApprovableToken.connect(user).approve(tokenId, ethers.constants.AddressZero, amount),
      ).to.be.revertedWith("Approve to the zero address");
    });
  });

  describe("Transfer", () => {
    let user1: Signer;
    let user2: Signer;
    let tokenId1: BigNumber;
    let tokenId2: BigNumber;
    let tokenId3: BigNumber;
    let amount0: BigNumber;
    let amount30: BigNumber;
    let amount50: BigNumber;
    let amount100: BigNumber;
    let amount110: BigNumber;
    let amount150: BigNumber;

    before(async () => {
      [user1, user2] = (await ethers.getSigners()).slice(4, 6);
      tokenId1 = BigNumber.from(1);
      tokenId2 = BigNumber.from(2);
      tokenId3 = BigNumber.from(3);
      amount0 = BigNumber.from(0);
      amount30 = BigNumber.from(30);
      amount50 = BigNumber.from(50);
      amount100 = BigNumber.from(100);
      amount110 = BigNumber.from(110);
      amount150 = BigNumber.from(150);
    });

    it("transfer single: should emit 'Approval' and revert transfer with 'Not authorized'", async () => {
      // mint tokens
      await singleApprovableToken.mint(await user1.getAddress(), tokenId1, amount100, "0x");

      // should emit 'Approval'
      await expect(singleApprovableToken.connect(user1).approve(tokenId1, admin.getAddress(), amount100))
        .to.emit(singleApprovableToken, "Approval")
        .withArgs(tokenId1, await user1.getAddress(), await admin.getAddress(), amount100);

      await expect(
        singleApprovableToken
          .connect(admin)
          .safeTransferFrom(await user1.getAddress(), await admin.getAddress(), tokenId1, amount110, "0x"),
      ).to.be.revertedWith("Not authorized");
    });

    it("transfer single: user should be able to move all funds", async () => {
      // should transfer tokens for user1
      await expect(
        await singleApprovableToken
          .connect(admin)
          .safeTransferFrom(await user1.getAddress(), await admin.getAddress(), tokenId1, amount100, "0x"),
      )
        .to.emit(singleApprovableToken, "TransferSingle")
        .withArgs(await admin.getAddress(), await user1.getAddress(), await admin.getAddress(), tokenId1, amount100);

      // check user balance
      expect(await singleApprovableToken.balanceOf(await user1.getAddress(), tokenId1)).to.equal(amount0);
    });

    it("transfer single: user should be able to move part of funds", async () => {
      // mint tokens
      await singleApprovableToken.mint(await user2.getAddress(), tokenId2, amount150, "0x");

      const amountToApprove = BigNumber.from(120);
      // should emit 'Approval'
      await expect(singleApprovableToken.connect(user2).approve(tokenId2, admin.getAddress(), amountToApprove))
        .to.emit(singleApprovableToken, "Approval")
        .withArgs(tokenId2, await user2.getAddress(), await admin.getAddress(), amountToApprove);

      const amountToTransfer = BigNumber.from(100);
      // should transfer tokens for user2
      await expect(
        await singleApprovableToken
          .connect(admin)
          .safeTransferFrom(await user2.getAddress(), await admin.getAddress(), tokenId2, amountToTransfer, "0x"),
      )
        .to.emit(singleApprovableToken, "TransferSingle")
        .withArgs(
          await admin.getAddress(),
          await user2.getAddress(),
          await admin.getAddress(),
          tokenId2,
          amountToTransfer,
        );

      // check user balance
      expect(await singleApprovableToken.balanceOf(await user2.getAddress(), tokenId2)).to.equal(amount50);
    });

    it("transfer single: user should be able to move funds directly in blokchain", async () => {
      const amountToTransfer = BigNumber.from(20);
      // should transfer tokens for user2
      await expect(
        await singleApprovableToken
          .connect(user2)
          .safeTransferFrom(await user2.getAddress(), await admin.getAddress(), tokenId2, amountToTransfer, "0x"),
      )
        .to.emit(singleApprovableToken, "TransferSingle")
        .withArgs(
          await user2.getAddress(),
          await user2.getAddress(),
          await admin.getAddress(),
          tokenId2,
          amountToTransfer,
        );

      // check user balance
      expect(await singleApprovableToken.balanceOf(await user2.getAddress(), tokenId2)).to.equal(amount30);
    });

    it("transfer batch: should emit 'Approval' and revert transfer with 'Not authorized'", async () => {
      // mint tokens
      await singleApprovableToken.mint(await user2.getAddress(), tokenId3, amount100, "0x");

      // should emit 'Approval'
      await expect(singleApprovableToken.connect(user2).approve(tokenId3, admin.getAddress(), amount100))
        .to.emit(singleApprovableToken, "Approval")
        .withArgs(tokenId3, await user2.getAddress(), await admin.getAddress(), amount100);

      await expect(
        singleApprovableToken
          .connect(admin)
          .safeBatchTransferFrom(
            await user2.getAddress(),
            await admin.getAddress(),
            [tokenId2, tokenId3],
            [amount30, amount100],
            "0x",
          ),
      ).to.be.revertedWith("Not authorized");
    });

    it("transfer batch: user should be able to move all funds by tokenId", async () => {
      // should emit 'Approval'
      await expect(singleApprovableToken.connect(user2).approve(tokenId2, admin.getAddress(), amount30))
        .to.emit(singleApprovableToken, "Approval")
        .withArgs(tokenId2, await user2.getAddress(), await admin.getAddress(), amount30);

      // should transfer tokens for user2
      await expect(
        await singleApprovableToken
          .connect(admin)
          .safeBatchTransferFrom(
            await user2.getAddress(),
            await admin.getAddress(),
            [tokenId2, tokenId3],
            [amount30, amount100],
            "0x",
          ),
      )
        .to.emit(singleApprovableToken, "TransferBatch")
        .withArgs(
          await admin.getAddress(),
          await user2.getAddress(),
          await admin.getAddress(),
          [tokenId2, tokenId3],
          [amount30, amount100],
        );

      // check user balance
      expect(await singleApprovableToken.balanceOf(await user2.getAddress(), tokenId2)).to.equal(amount0);
      expect(await singleApprovableToken.balanceOf(await user2.getAddress(), tokenId3)).to.equal(amount0);
    });

    it("transfer batch: user should be able to move all funds by tokenId - multiple users", async () => {
      // mint tokens
      await singleApprovableToken.mint(await user1.getAddress(), tokenId1, amount100, "0x");
      await singleApprovableToken.mint(await user1.getAddress(), tokenId3, amount150, "0x");
      await singleApprovableToken.mint(await user2.getAddress(), tokenId2, amount30, "0x");
      await singleApprovableToken.mint(await user2.getAddress(), tokenId3, amount50, "0x");

      // should emit 'Approval'
      await singleApprovableToken.connect(user1).approve(tokenId1, admin.getAddress(), amount100);
      await singleApprovableToken.connect(user1).approve(tokenId3, admin.getAddress(), amount150);
      await singleApprovableToken.connect(user2).approve(tokenId2, admin.getAddress(), amount30);
      await singleApprovableToken.connect(user2).approve(tokenId3, admin.getAddress(), amount50);

      // should transfer tokens for user1
      await expect(
        await singleApprovableToken
          .connect(admin)
          .safeBatchTransferFrom(
            await user1.getAddress(),
            await admin.getAddress(),
            [tokenId1, tokenId3],
            [amount50, amount100],
            "0x",
          ),
      )
        .to.emit(singleApprovableToken, "TransferBatch")
        .withArgs(
          await admin.getAddress(),
          await user1.getAddress(),
          await admin.getAddress(),
          [tokenId1, tokenId3],
          [amount50, amount100],
        );

      // should transfer tokens for user2
      await expect(
        await singleApprovableToken
          .connect(admin)
          .safeBatchTransferFrom(
            await user2.getAddress(),
            await admin.getAddress(),
            [tokenId2, tokenId3],
            [amount30, amount50],
            "0x",
          ),
      )
        .to.emit(singleApprovableToken, "TransferBatch")
        .withArgs(
          await admin.getAddress(),
          await user2.getAddress(),
          await admin.getAddress(),
          [tokenId2, tokenId3],
          [amount30, amount50],
        );

      // check user balance
      expect(await singleApprovableToken.balanceOf(await user1.getAddress(), tokenId1)).to.equal(amount50);
      expect(await singleApprovableToken.balanceOf(await user1.getAddress(), tokenId3)).to.equal(amount50);
      expect(await singleApprovableToken.balanceOf(await user2.getAddress(), tokenId2)).to.equal(amount0);
      expect(await singleApprovableToken.balanceOf(await user2.getAddress(), tokenId3)).to.equal(amount0);
    });

    it("transfer batch: user should be able to move funds directly in blokchain", async () => {
      // should transfer tokens for user2
      await expect(
        await singleApprovableToken
          .connect(user1)
          .safeBatchTransferFrom(
            await user1.getAddress(),
            await admin.getAddress(),
            [tokenId1, tokenId3],
            [amount30, amount50],
            "0x",
          ),
      )
        .to.emit(singleApprovableToken, "TransferBatch")
        .withArgs(
          await user1.getAddress(),
          await user1.getAddress(),
          await admin.getAddress(),
          [tokenId1, tokenId3],
          [amount30, amount50],
        );

      // check user balance
      expect(await singleApprovableToken.balanceOf(await user1.getAddress(), tokenId1)).to.equal(BigNumber.from(20));
      expect(await singleApprovableToken.balanceOf(await user1.getAddress(), tokenId3)).to.equal(amount0);
    });
  });

  describe("Validate URI", () => {
    let tokenURI: string;
    let tokenId: BigNumber;

    const BASE_URI = "https://test2.com/";

    beforeEach(async () => {
      // set base URI
      await singleApprovableToken.connect(admin).setBaseURI(BASE_URI);
    });

    it("setURI: should return encodePacked(_baseURI, tokenURI) ", async () => {
      tokenURI = "nft_1";
      tokenId = BigNumber.from("1");

      // should set token URI
      await singleApprovableToken.connect(admin).setURI(tokenId, tokenURI);
      // validate token URI
      expect(await singleApprovableToken.connect(admin).uri(tokenId)).to.be.equal(BASE_URI + tokenURI);
    });

    it("setURI: should return super.uri(tokenId) ERC1155._uri ", async () => {
      tokenURI = "";
      tokenId = BigNumber.from("1");

      // should set token URI
      await singleApprovableToken.connect(admin).setURI(tokenId, tokenURI);
      // validate token URI
      expect(await singleApprovableToken.connect(admin).uri(tokenId)).to.be.equal(CONTRACT_URI);
    });
  });
});
