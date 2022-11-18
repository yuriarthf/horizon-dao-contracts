// RealEstateERC1155.test.ts: Unit tests for RealEstateERC1155 token

// Solidity extension for chai
import { solidity } from "ethereum-waffle";

// Use Chai for testing
import chai from "chai";
import { expect } from "chai";
// Setup chai plugins
chai.use(solidity);

// Import contract types
import type { RealEstateERC1155, RealEstateERC1155__factory } from "../../typechain-types";

// HardhatRuntimeEnvironment
import { ethers, upgrades } from "hardhat";

// Get BigNumber
import { BigNumber } from "@ethersproject/bignumber";
import { Signer } from "@ethersproject/abstract-signer";

describe("RealEstateERC1155 Unit Tests", () => {
  let admin: Signer;
  let owner: Signer;
  let minter: Signer;
  let burner: Signer;
  let realEstateToken: RealEstateERC1155;

  const URI = "https://test.com/";
  const NAME = "Real Estate NFT";
  const SYMBOL = "reNFT";

  before(async () => {
    // get signers
    [, admin, owner, minter, burner] = await ethers.getSigners();

    // deploy RealEstateERC1155 contract
    const realEstateTokenFactory = <RealEstateERC1155__factory>await ethers.getContractFactory("RealEstateERC1155");
    realEstateToken = <RealEstateERC1155>(
      await upgrades.deployProxy(realEstateTokenFactory, [URI, await admin.getAddress(), await owner.getAddress()])
    );
  });

  it("name: should be equal to NAME", async () => {
    // check RealEstateERC1155 name
    expect(await realEstateToken.name()).to.be.equal(NAME);
  });

  it("symbol: should be equal to SYMBOL", async () => {
    // heck RealEstateERC1155 symbol
    expect(await realEstateToken.symbol()).to.be.equal(SYMBOL);
  });

  it("setMinter: should revert with '!admin' if caller is not the admin", async () => {
    // should revert with "!admin" message
    await expect(realEstateToken.setMinter(minter.getAddress())).to.be.revertedWith("!admin");
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

  it("setBurner: should revert with '!admin' if caller is not the admin", async () => {
    // should revert with "!admin" message
    await expect(realEstateToken.setBurner(minter.getAddress())).to.be.revertedWith("!admin");
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
    let realEstateReceiver: Signer;

    const FIRST_MINT = BigNumber.from("1000");
    const ADDITIONAL_FIRST_MINT = BigNumber.from("500");
    const SECOND_MINT = BigNumber.from("2000");

    let currentId = BigNumber.from("0");

    before(async () => {
      // get realEstateReceiver
      [realEstateReceiver] = (await ethers.getSigners()).slice(5);
    });

    it("mint: revert if caller is not the minter", async () => {
      // should revert with "!minter" message
      await expect(realEstateToken.mint(currentId, realEstateReceiver.getAddress(), FIRST_MINT)).to.be.revertedWith(
        "!minter",
      );
    });

    it("mint: first mint should increase currentId and emit 'RealEstateNFTMinted' event", async () => {
      // should emit "RealEstateNFTMinted"
      await expect(realEstateToken.connect(minter).mint(currentId, realEstateReceiver.getAddress(), FIRST_MINT))
        .to.emit(realEstateToken, "RealEstateNFTMinted")
        .withArgs(currentId, await minter.getAddress(), await realEstateReceiver.getAddress(), FIRST_MINT);

      // increment currentId
      currentId = currentId.add(1);

      // check if it matches with contract's currentId
      expect(await realEstateToken.nextRealEstateId()).to.be.equal(currentId);

      // check realEstateReceiver balance
      expect(await realEstateToken.balanceOf(realEstateReceiver.getAddress(), currentId.sub(1))).to.be.equal(
        FIRST_MINT,
      );
    });

    it("mint: mint additional tokens on existing reNFT collection should not increment currentId", async () => {
      // mint additional tokens
      await realEstateToken
        .connect(minter)
        .mint(currentId.sub(1), realEstateReceiver.getAddress(), ADDITIONAL_FIRST_MINT);

      // check realEstateReceiver balance
      expect(await realEstateToken.balanceOf(realEstateReceiver.getAddress(), currentId.sub(1))).to.be.equal(
        FIRST_MINT.add(ADDITIONAL_FIRST_MINT),
      );

      // check contract's current ID
      expect(await realEstateToken.nextRealEstateId()).to.be.equal(currentId);
    });

    it("mint: reverts with 'IDs should be sequential' message if new collection ID is not sequential", async () => {
      // should revert with "IDs should be sequential"
      await expect(
        realEstateToken.connect(minter).mint(currentId.add(1), realEstateReceiver.getAddress(), SECOND_MINT),
      ).to.be.revertedWith("IDs should be sequential");
    });

    it("mint: new reNFT collection should increment currentId", async () => {
      // mint new reNFT collection
      await expect(realEstateToken.connect(minter).mint(currentId, realEstateReceiver.getAddress(), SECOND_MINT))
        .to.emit(realEstateToken, "RealEstateNFTMinted")
        .withArgs(currentId, await minter.getAddress(), await realEstateReceiver.getAddress(), SECOND_MINT);

      // increment currentId and check contract value
      currentId = currentId.add(1);
      expect(await realEstateToken.nextRealEstateId()).to.be.equal(currentId);

      // check realEstateReceiver balance
      expect(await realEstateToken.balanceOf(realEstateReceiver.getAddress(), currentId.sub(1))).to.be.equal(
        SECOND_MINT,
      );
    });

    describe("burn event", () => {
      it("burn: reverts with '!burner' message if caller is not the burner", async () => {
        // should revert with "!burner"
        await expect(
          realEstateToken.connect(realEstateReceiver).burn(currentId.sub(1), SECOND_MINT),
        ).to.be.revertedWith("!burner");
      });

      it("burn: should emit 'RealEstateNFTBurned' when successful", async () => {
        // transfer tokens to burner
        await realEstateToken
          .connect(realEstateReceiver)
          .safeTransferFrom(
            realEstateReceiver.getAddress(),
            burner.getAddress(),
            currentId.sub(1),
            SECOND_MINT,
            ethers.utils.toUtf8Bytes(""),
          );

        // check balances
        expect(await realEstateToken.balanceOf(realEstateReceiver.getAddress(), currentId.sub(1))).to.be.equal(
          BigNumber.from(0),
        );
        expect(await realEstateToken.balanceOf(burner.getAddress(), currentId.sub(1))).to.be.equal(SECOND_MINT);

        // burn all tokens
        await expect(realEstateToken.connect(burner).burn(currentId.sub(1), SECOND_MINT))
          .to.emit(realEstateToken, "RealEstateNFTBurned")
          .withArgs(currentId.sub(1), await burner.getAddress(), SECOND_MINT);

        // check burner balance
        expect(await realEstateToken.balanceOf(burner.getAddress(), currentId.sub(1))).to.be.equal(BigNumber.from(0));
      });
    });
  });
});
