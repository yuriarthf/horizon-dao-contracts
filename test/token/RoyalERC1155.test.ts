// RoyalERC1155.test.ts: Unit tests for RoyalERC1155 token

// Solidity extension for chai
import { solidity } from "ethereum-waffle";

// Use Chai for testing
import chai from "chai";
import { expect } from "chai";
// Setup chai plugins
chai.use(solidity);

// Import contract mocks
import { RoyalERC1155Mock, RoyalERC1155Mock__factory } from "../../typechain-types";

// HardhatRuntimeEnvironment
import { ethers } from "hardhat";

// Get BigNumber
import { BigNumber } from "@ethersproject/bignumber";
import { Signer } from "@ethersproject/abstract-signer";

describe("RoyalERC1155 Unit Tests", () => {
  // eslint-disable-next-line @typescript-eslint/no-unused-vars
  let deployer: Signer;
  let admin: Signer;
  let owner: Signer;
  let user: Signer;
  let royalToken: RoyalERC1155Mock;

  const CONTRACT_URI = "https://test.com/";

  before(async () => {
    // get signers
    [deployer, admin, owner, user] = await ethers.getSigners();
  });

  beforeEach(async () => {
    // deploy royalToken contract
    const royalTokenFactory = <RoyalERC1155Mock__factory>await ethers.getContractFactory("RoyalERC1155Mock");
    royalToken = await royalTokenFactory.deploy(CONTRACT_URI, admin.getAddress(), owner.getAddress());
    await royalToken.deployed();
  });

  it("setAdmin: should revert with '!admin' if caller is not the admin", async () => {
    // should revert with "!admin" message
    await expect(royalToken.setAdmin(admin.getAddress())).to.be.revertedWith("!admin");
  });

  it("setAdmin: should revert with 'admin == _admin' message when setting the same admin", async () => {
    // should revert with "admin == _admin" message
    await expect(royalToken.connect(admin).setAdmin(admin.getAddress())).to.be.revertedWith("admin == _admin");
  });

  it("isOwner: should return true if owner", async () => {
    // should return true
    expect(await royalToken.isOwner(await owner.getAddress())).to.be.equal(true);
  });

  describe("Check if admin is updated", () => {
    let newAdmin: Signer;

    before(async () => {
      [newAdmin] = (await ethers.getSigners()).slice(4);
    });
    it("setAdmin: should emit 'SetAdmin' on success", async () => {
      // should emit "NewAdmin"
      await expect(royalToken.connect(admin).setAdmin(newAdmin.getAddress()))
        .to.emit(royalToken, "NewAdmin")
        .withArgs(await newAdmin.getAddress());
    });

    it("setAdmin: should revert with '!admin' if caller is not the admin", async () => {
      // set new admin
      await royalToken.connect(admin).setAdmin(newAdmin.getAddress());
      // should revert with "!admin" message
      await expect(royalToken.connect(admin).setAdmin(admin.getAddress())).to.be.revertedWith("!admin");
    });
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
      const invalidAddress = "0x0000000000000000000000000000000000000000";
      // should revert with "ERC2981: invalid receiver" message
      await expect(royalToken.connect(admin).setDefaultRoyalty(invalidAddress, FEE_DENOMINATOR)).to.be.revertedWith(
        "ERC2981: invalid receiver",
      );
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
      const invalidAddress = "0x0000000000000000000000000000000000000000";
      // should revert with "ERC2981: invalid receiver" message
      await expect(royalToken.connect(admin).setDefaultRoyalty(invalidAddress, ROYALTY_FRACTION)).to.be.revertedWith(
        "ERC2981: invalid receiver",
      );
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

  describe("Validate URI", () => {
    let tokenURI: string;
    let tokenId: BigNumber;

    const BASE_URI = "https://test2.com/";

    beforeEach(async () => {
      // set base URI
      await royalToken.connect(admin).setBaseURI(BASE_URI);
    });

    it("setBaseURI: should revert with '!admin' if caller is not the admin", async () => {
      // should revert with "!admin" message
      await expect(royalToken.setBaseURI(BASE_URI)).to.be.revertedWith("!admin");
    });

    it("setURI: should revert with '!admin' if caller is not the admin", async () => {
      tokenURI = "nft_1";
      tokenId = BigNumber.from("1");

      // should revert with "!admin" message
      await expect(royalToken.setURI(tokenId, tokenURI)).to.be.revertedWith("!admin");
    });

    it("setURI: should return encodePacked(_baseURI, tokenURI) ", async () => {
      tokenURI = "nft_1";
      tokenId = BigNumber.from("1");

      // should set token URI
      await royalToken.connect(admin).setURI(tokenId, tokenURI);
      // validate token URI
      expect(await royalToken.connect(admin).uri(tokenId)).to.be.equal(BASE_URI + tokenURI);
    });

    it("setURI: should return super.uri(tokenId) ERC1155._uri ", async () => {
      tokenURI = "";
      tokenId = BigNumber.from("1");

      // should set token URI
      await royalToken.connect(admin).setURI(tokenId, tokenURI);
      // validate token URI
      expect(await royalToken.connect(admin).uri(tokenId)).to.be.equal(CONTRACT_URI);
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
