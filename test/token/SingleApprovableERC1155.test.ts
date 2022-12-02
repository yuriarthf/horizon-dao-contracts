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
  let owner: Signer;
  let user: Signer;
  let singleApprovableToken: SingleApprovableERC1155Mock;

  const CONTRACT_URI = "https://test.com/";

  before(async () => {
    // get signers
    [, admin, owner, user] = await ethers.getSigners();

    // deploy royalToken contract
    const singleApprovableFactory = <SingleApprovableERC1155Mock__factory>(
      await ethers.getContractFactory("SingleApprovableERC1155Mock")
    );

    singleApprovableToken = await singleApprovableFactory.deploy(CONTRACT_URI);
    await singleApprovableToken.deployed();
  });

  describe("Approval", () => {
    let tokenId: BigNumber;
    let amount: BigNumber;

    before(async () => {
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

    it("approve: should emit 'Approval' and revert tranfer with 'Not auuthorized'", async () => {
      // should transfer amount
      await singleApprovableToken.mint(await user.getAddress(), tokenId, amount, "0x");

      // should emit 'Approval'
      await expect(singleApprovableToken.connect(user).approve(tokenId, admin.getAddress(), amount))
        .to.emit(singleApprovableToken, "Approval")
        .withArgs(tokenId, await user.getAddress(), await admin.getAddress(), amount);

      await expect(
        singleApprovableToken
          .connect(admin)
          .safeTransferFrom(await user.getAddress(), await admin.getAddress(), tokenId, BigNumber.from(110), "0x"),
      ).to.be.revertedWith("Not authorized");
    });

    it("approve: user should be able to move funds", async () => {
      // should transfer amount
      await expect(
        await singleApprovableToken
          .connect(admin)
          .safeTransferFrom(await user.getAddress(), await admin.getAddress(), tokenId, amount, "0x"),
      )
        .to.emit(singleApprovableToken, "TransferSingle")
        .withArgs(await admin.getAddress(), await user.getAddress(), await admin.getAddress(), tokenId, amount);

      // check user balance
      expect(await singleApprovableToken.balanceOf(await user.getAddress(), tokenId)).to.equal(BigNumber.from(0));
    });
  });

  // safeBatchTransferFrom
  // uri
  // _beforeTokenTransfer ??
});
