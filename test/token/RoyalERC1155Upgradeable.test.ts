// RoyalERC1155.test.ts: Unit tests for RoyalERC1155 token

// Solidity extension for chai
import { solidity } from "ethereum-waffle";

// Use Chai for testing
import chai from "chai";
import { expect } from "chai";
// Setup chai plugins
chai.use(solidity);

// Import contract mocks
import { RoyalERC1155UpgradeableMock } from "../../typechain-types";

// HardhatRuntimeEnvironment
import { ethers, upgrades } from "hardhat";

// Get BigNumber
import { BigNumber } from "@ethersproject/bignumber";
import { Signer } from "@ethersproject/abstract-signer";

describe("RoyalERC1155Upgradeable Unit Tests", () => {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  let deployer: Signer;
  let admin: Signer;
  let owner: Signer;
  let user: Signer;
  let royalToken: RoyalERC1155UpgradeableMock;

  const CONTRACT_URI = "https://test.com/";

  before(async () => {
    // get signers
    [deployer, admin, owner, user] = await ethers.getSigners();
  });

  beforeEach(async () => {
    // deploy royalToken contract
    royalToken = <RoyalERC1155UpgradeableMock>(
      await upgrades.deployProxy(await ethers.getContractFactory("RoyalERC1155UpgradeableMock"), [
        CONTRACT_URI,
        await admin.getAddress(),
        await owner.getAddress(),
      ])
    );
  });

  it("Initialization fails if init functions called outside of initialize function", async () => {
    // should revert with 'Initializable: contract is not initializing' message
    await expect(royalToken.initChained(CONTRACT_URI, admin.getAddress(), owner.getAddress())).to.be.revertedWith(
      "Initializable: contract is not initializing",
    );
    await expect(royalToken.initUnchained(owner.getAddress())).to.be.revertedWith(
      "Initializable: contract is not initializing",
    );
  });

  it("isOwner: Should return true if address if the owner and false otherwise", async () => {
    // should return true
    expect(await royalToken.isOwner(owner.getAddress())).to.be.true;

    // should return false
    expect(await royalToken.isOwner(admin.getAddress())).to.be.false;
  });

  describe("Set the default royalties info (for all token IDs)", () => {
    let royaltyReceiver: Signer;

    const FEE_DENOMINATOR = BigNumber.from("8000");

    before(async () => {
      [royaltyReceiver] = (await ethers.getSigners()).slice(5);
    });

    it("setDefaultRoyalties: should revert with '!admin' if caller is not the admin", async () => {
      // should revert with "!admin" message
      await expect(
        royalToken.setDefaultRoyalty(await royaltyReceiver.getAddress(), FEE_DENOMINATOR),
      ).to.be.revertedWith("!admin");
    });

    it("setDefaultRoyalty: should revert if default value for setDefaultRoyalt is greater than allowed in contract", async () => {
      const feeDenominator = BigNumber.from("15000");
      // should revert with "ERC2981: royalty fee will exceed salePrice" message
      await expect(
        royalToken.connect(admin).setDefaultRoyalty(royaltyReceiver.getAddress(), feeDenominator),
      ).to.be.revertedWith("ERC2981: royalty fee will exceed salePrice");
    });

    it("setDefaultRoyalty: should revert if invalid address", async () => {
      // should revert with "ERC2981: invalid receiver" message
      await expect(
        royalToken.connect(admin).setDefaultRoyalty(ethers.constants.AddressZero, FEE_DENOMINATOR),
      ).to.be.revertedWith("ERC2981: invalid receiver");
    });

    it("setDefaultRoyalty: should emit 'SetDefaultRoyalties' on success", async () => {
      // should emit "SetTokenRoyalty"
      await expect(royalToken.connect(admin).setDefaultRoyalty(royaltyReceiver.getAddress(), FEE_DENOMINATOR))
        .to.emit(royalToken, "SetDefaultRoyalties")
        .withArgs(await admin.getAddress(), await royaltyReceiver.getAddress(), FEE_DENOMINATOR);
    });
  });

  describe("Set royalties info for a specific token ID", () => {
    let royaltyReceiver: Signer;

    const ROYALTY_FRACTION = BigNumber.from("8000");

    before(async () => {
      [royaltyReceiver] = (await ethers.getSigners()).slice(6);
    });

    it("setTokenRoyalty: should revert with '!admin' if caller is not the admin", async () => {
      // should revert with "!admin" message
      await expect(
        royalToken.setTokenRoyalty(1, await royaltyReceiver.getAddress(), ROYALTY_FRACTION),
      ).to.be.revertedWith("!admin");
    });

    it("setTokenRoyalty: should revert if default value for setDefaultRoyalt is greater than allowed in contract", async () => {
      const royaltyFraction = BigNumber.from("15000");
      // should revert with "ERC2981: royalty fee will exceed salePrice" message
      await expect(
        royalToken.connect(admin).setDefaultRoyalty(royaltyReceiver.getAddress(), royaltyFraction),
      ).to.be.revertedWith("ERC2981: royalty fee will exceed salePrice");
    });

    it("setTokenRoyalty: should revert if invalid address", async () => {
      // should revert with "ERC2981: invalid receiver" message
      await expect(
        royalToken.connect(admin).setDefaultRoyalty(ethers.constants.AddressZero, ROYALTY_FRACTION),
      ).to.be.revertedWith("ERC2981: invalid receiver");
    });

    it("setTokenRoyalty: should emit 'SetDefaultRoyalties' on success", async () => {
      const tokenId = BigNumber.from("1");
      const contractFeeDenominator = await royalToken.feeDenominator();
      // should emit "SetTokenRoyalty"
      await expect(royalToken.connect(admin).setTokenRoyalty(tokenId, royaltyReceiver.getAddress(), ROYALTY_FRACTION))
        .to.emit(royalToken, "SetTokenRoyalty")
        .withArgs(await admin.getAddress(), tokenId, await royaltyReceiver.getAddress(), ROYALTY_FRACTION);

      const salesPrice = BigNumber.from("1500");
      const royaltyAmount = salesPrice.mul(ROYALTY_FRACTION).div(contractFeeDenominator);

      // get royalty amount by token id
      const [receiver, amount] = await royalToken.royaltyInfo(tokenId, salesPrice);

      expect(receiver).to.be.equal(await royaltyReceiver.getAddress());
      expect(amount).to.be.equal(royaltyAmount);
    });
  });

  describe("Set contract URI", () => {
    const NEW_URI = "https://test2.com/";

    it("setContractURI: should revert with '!admin' if caller is not the admin", async () => {
      // should revert with "!admin" message
      await expect(royalToken.setContractURI(NEW_URI)).to.be.revertedWith("!admin");
    });

    it("setContractURI: should emit 'SetContractURI' on success", async () => {
      // should emit "SetContractURI"
      await expect(royalToken.connect(admin).setContractURI(NEW_URI))
        .to.emit(royalToken, "ContractURIUpdated")
        .withArgs(await admin.getAddress(), NEW_URI);

      // validate new contract URI
      expect(await royalToken.connect(admin).contractURI()).to.be.equal(NEW_URI);
    });
  });

  it("supportsInterface: Supports IERC165, IERC2981 and IERC1155", async () => {
    // Interface IDs
    const Ierc2981InterfaceId = "0x2a55205a";
    const Ierc1155InterfaceId = "0xd9b67a26";

    // Check if interfaces are supported
    expect(await royalToken.supportsInterface(Ierc2981InterfaceId)).to.be.true;
    expect(await royalToken.supportsInterface(Ierc1155InterfaceId)).to.be.true;
  });

  describe("Transfer ownership", () => {
    let newOwner: Signer;

    before(async () => {
      [newOwner] = (await ethers.getSigners()).slice(6);
    });

    it("transferOwnership: should revert with '!admin' if caller is not the admin", async () => {
      // should revert with "!admin" message
      await expect(royalToken.transferOwnership(await user.getAddress())).to.be.revertedWith("!admin");
    });

    it("transferOwnership: should emit 'OwnershipTransferred' on success", async () => {
      // should emit "OwnershipTransferred"
      await expect(royalToken.connect(admin).transferOwnership(await newOwner.getAddress()))
        .to.emit(royalToken, "OwnershipTransferred")
        .withArgs(await owner.getAddress(), await newOwner.getAddress());

      // validate new owner
      expect(await royalToken.connect(admin).owner()).to.be.equal(await newOwner.getAddress());
    });
  });
});
