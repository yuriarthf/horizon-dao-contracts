// PioneerERC1155.test.ts: Unit tests for PioneerERC1155 token

// Solidity extension for chai
import { solidity } from "ethereum-waffle";

// Use Chai for testing
import chai from "chai";
import { expect } from "chai";
// Setup chai plugins
chai.use(solidity);

// Import contract types
import type {
  PioneerERC1155,
  EthBlockerMock,
  PioneerERC1155__factory,
  EthBlockerMock__factory,
} from "../../typechain-types";

// HardhatRuntimeEnvironment
import { ethers } from "hardhat";

// Get BigNumber
import { BigNumber, BigNumberish } from "@ethersproject/bignumber";
import { Wallet } from "@ethersproject/wallet";
import { Signer } from "@ethersproject/abstract-signer";

// Import BigNumber utility functions
import { randomUint256 } from "../utils/bn_utils";

// Import pioneer tree constructor
import { PioneerTree } from "./utils/pioneer_tree";

// Import airdrop tree constructor and types
import { AirdropTree } from "./utils/airdrop_tree";
import type { Airdrop } from "../types";

// Import EVM utils
import { setBlockTimestamp, setAccountBalance } from "../utils/evm_utils";

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

  const PUBLIC_SALE_OFFSET = BigNumber.from("604800");
  const NUMBER_OF_WHITELISTED_WALLETS = 50;

  enum Pioneer {
    BRONZE,
    SILVER,
    GOLD,
  }

  function name(id: Pioneer) {
    switch (id) {
      case Pioneer.BRONZE:
        return "Bronze Horizon Pioneer Badge";
      case Pioneer.SILVER:
        return "Silver Horizon Pioneer Badge";
      case Pioneer.GOLD:
        return "Gold Horizon Pioneer Badge";
      default:
        throw new Error("Invalid id");
    }
  }

  function description(id: Pioneer) {
    switch (id) {
      case Pioneer.BRONZE:
        return "";
      case Pioneer.SILVER:
        return "";
      case Pioneer.GOLD:
        return "";
      default:
        throw new Error("Invalid id");
    }
  }

  function metadata(id: Pioneer) {
    return JSON.stringify({
      name: name(id),
      description: description(id),
      image: IMAGE_URI + id.toString(),
    });
  }

  function uri(id: Pioneer) {
    return `data:application/json;base64,${Buffer.from(metadata(id)).toString("base64")}`;
  }

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

  it("Check tokenName", async () => {
    // iterate over all pioneerNFT types and compare the token names
    for (let id = Pioneer.BRONZE; id <= Pioneer.GOLD; id++) {
      expect(await pioneerToken.name(id)).to.be.equal(name(id));
    }
  });

  it("tokenName: should revert if provided id is greater than Pioneer.GOLD", async () => {
    // should revert with "Invalid token ID"
    await expect(pioneerToken.name(BigNumber.from(Pioneer.GOLD).add(1))).to.be.revertedWith("Invalid token ID");
  });

  it("Check tokenDescription", async () => {
    // iterate over all pioneerNFT types and compare the token descriptions
    for (let id = Pioneer.BRONZE; id <= Pioneer.GOLD; id++) {
      expect(await pioneerToken.description(id)).to.be.equal(description(id));
    }
  });

  it("tokenDescription: should revert if provided id is greater than Pioneer.GOLD", async () => {
    // should revert with "Invalid token ID"
    await expect(pioneerToken.description(BigNumber.from(Pioneer.GOLD).add(1))).to.be.revertedWith("Invalid token ID");
  });

  it("Check tokenMetadata", async () => {
    // iterate over all pioneerNFT types and compare the token metadata
    for (let id = Pioneer.BRONZE; id <= Pioneer.GOLD; id++) {
      expect(await pioneerToken.metadata(id)).to.be.equal(metadata(id));
    }
  });

  it("Check uri", async () => {
    // iterate over all pioneerNFT types and compare the token's uri
    for (let id = Pioneer.BRONZE; id <= Pioneer.GOLD; id++) {
      expect(await pioneerToken.uri(id)).to.be.equal(uri(id));
    }
  });

  it("uri: should revert if provided id is greater than Pioneer.GOLD", async () => {
    // should revert with "Invalid token ID"
    await expect(pioneerToken.uri(BigNumber.from(Pioneer.GOLD).add(1))).to.be.revertedWith("Invalid token ID");
  });

  it("Make sure saleInitialized return false before Sale is initialized", async () => {
    // saleInitialized should return false
    expect(await pioneerToken.saleInitialized()).to.be.false;
  });

  it("Check imageURI", async () => {
    // iterate over all pioneerNFT types and compare the imageUri
    let imageUri: string;
    for (let id = Pioneer.BRONZE; id <= Pioneer.GOLD; id++) {
      imageUri = await pioneerToken.imageURI(id);
      expect(imageUri).to.be.equal(IMAGE_URI + id.toString());
    }
  });

  it("imageURI: should revert if the caller is not the admin", async () => {
    // should revert with "!admin" message
    await expect(pioneerToken.setImageBaseURI(IMAGE_URI)).to.revertedWith("!admin");
  });

  it("imageURI: should revert if it's zero", async () => {
    // set imageURI to empty string
    await expect(pioneerToken.connect(admin).setImageBaseURI("")).to.emit(pioneerToken, "NewImageUri");

    // should revert with "!baseURI"
    await expect(pioneerToken.imageURI(Pioneer.GOLD)).to.be.revertedWith("!baseURI");

    // set imageURI back to IMAGE_URI
    await pioneerToken.connect(admin).setImageBaseURI(IMAGE_URI);
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

    it("Reverts if chance array items are not monotonically increasing", async () => {
      // get deploy transaction
      const deployTransaction = pioneerTokenFactory
        .connect(deployer)
        .deploy(
          IMAGE_URI,
          admin.getAddress(),
          owner.getAddress(),
          PUBLIC_TOKEN_UNIT_PRICE,
          WHITELIST_TOKEN_UNIT_PRICE,
          [CHANCES[1], CHANCES[0], CHANCES[2]],
        );

      // should revert with "Invalid _chance array" message
      await expect(deployTransaction).to.be.revertedWith("Invalid _chance array");
    });
  });

  describe("Private claiming", () => {
    let privateSigner1: Signer;
    let privateSigner2: Signer;
    let privateSigner3: Signer;
    let privateSigner4: Signer;
    let privateWhitelistTree: PioneerTree;

    before(async () => {
      // get private whitelist signers
      [privateSigner1, privateSigner2, privateSigner3, privateSigner4] = (await ethers.getSigners()).slice(4);

      // build private whitelist tree
      privateWhitelistTree = new PioneerTree([
        await privateSigner1.getAddress(),
        await privateSigner2.getAddress(),
        await privateSigner3.getAddress(),
        await privateSigner4.getAddress(),
      ]);
    });

    it("setPrivateRoot: revert if caller is not admin", async () => {
      // Should revert with "!admin" message
      await expect(pioneerToken.setPrivateRoot(privateWhitelistTree.root)).to.be.revertedWith("!admin");
    });

    it("setPrivateRoot: should emit 'PrivateMerkleRootSet' event when successful", async () => {
      // Should emit "PrivateMerkleRootSet" event
      await expect(pioneerToken.connect(admin).setPrivateRoot(privateWhitelistTree.root))
        .to.emit(pioneerToken, "PrivateMerkleRootSet")
        .withArgs(await admin.getAddress(), privateWhitelistTree.root);
    });

    it("setPrivateRoot: revert if root was already set", async () => {
      // Should revert with "Merkle root already set" message
      await expect(pioneerToken.connect(admin).setPrivateRoot(privateWhitelistTree.root)).to.be.revertedWith(
        "Merkle root already set",
      );
    });

    it("privateClaim: successful claims", async () => {
      // Private whitelisted signers array
      const privateSigners = [privateSigner1, privateSigner2, privateSigner3, privateSigner4];

      // claim tokens
      for (let i = 0; i < privateSigners.length; i++) {
        await expect(pioneerToken.connect(privateSigners[i]).privateClaim(privateWhitelistTree.proofsFromIndex(i)))
          .to.emit(pioneerToken, "PrivateClaim")
          .withArgs(await privateSigners[i].getAddress());
        expect(await pioneerToken.userPrivateClaimed(privateSigners[i].getAddress())).to.be.true;
        expect(await pioneerToken.balanceOf(privateSigners[i].getAddress(), Pioneer.GOLD)).to.be.equal(
          BigNumber.from(1),
        );
      }
    });

    it("privateClaim: trying to claim again should revert", async () => {
      // should revert with "claimed" message
      await expect(
        pioneerToken.connect(privateSigner1).privateClaim(privateWhitelistTree.proofsFromIndex(0)),
      ).to.be.revertedWith("claimed");
    });

    it("privateClaim: claiming with a non-whitelisted address should revert", async () => {
      // should revert with "!root" message
      await expect(pioneerToken.connect(user).privateClaim(privateWhitelistTree.proofsFromIndex(0))).to.be.revertedWith(
        "!root",
      );
    });
  });

  it("initializeSale: revert if merkle root is zero", async () => {
    // should revert with "Invalid Merkle root" message
    await expect(
      pioneerToken
        .connect(admin)
        .initializeSale(ethers.utils.hexZeroPad(ethers.utils.hexlify(0), 32), PUBLIC_SALE_OFFSET),
    ).to.be.revertedWith("Invalid Merkle root");
  });

  it("initializeSale: revert if callet is not the admin", async () => {
    // should revert with "!admin" message
    await expect(
      pioneerToken.initializeSale(ethers.utils.hexZeroPad(ethers.utils.hexlify(0), 32), PUBLIC_SALE_OFFSET),
    ).to.be.revertedWith("!admin");
  });

  describe("Sale begins", () => {
    let whitelistedWallets: Wallet[];
    let whitelistedMerkleTree: PioneerTree;

    const AMOUNT_TO_PURCHASE = BigNumber.from(1);

    before(async () => {
      // get random whitelisted wallets
      whitelistedWallets = [];
      const whitelisteAddresses = [];
      for (let i = 0; i < NUMBER_OF_WHITELISTED_WALLETS; i++) {
        whitelistedWallets.push(ethers.Wallet.createRandom().connect(ethers.provider));
        whitelisteAddresses.push(await whitelistedWallets[i].getAddress());
        await setAccountBalance(
          await whitelistedWallets[i].getAddress(),
          ethers.utils.parseEther("100000000").toHexString(),
        );
      }

      // create merkle tree
      whitelistedMerkleTree = new PioneerTree(whitelisteAddresses);
    });

    it("withdraw: should revert with 'No ethers to withdraw' message when ether balance is zero", async () => {
      // should revert with "No ethers to withdraw"
      await expect(pioneerToken.connect(admin).withdraw(admin.getAddress())).to.be.revertedWith(
        "No ethers to withdraw",
      );
    });

    it("whitelistPurchase: should revert with error message '!initialized' before sale initialization", async () => {
      // amount to purchase
      // should revert with "!initialized" message
      await expect(
        pioneerToken
          .connect(whitelistedWallets[0])
          .whitelistPurchase(AMOUNT_TO_PURCHASE, whitelistedMerkleTree.proofsFromIndex(0), {
            value: AMOUNT_TO_PURCHASE.mul(WHITELIST_TOKEN_UNIT_PRICE),
          }),
      ).to.be.revertedWith("!initialized");
    });

    it("initializeSale: should emit 'SaleInitialized' when successful", async () => {
      // should emit "SaleInitialized" event
      await expect(pioneerToken.connect(admin).initializeSale(whitelistedMerkleTree.root, PUBLIC_SALE_OFFSET)).to.emit(
        pioneerToken,
        "SaleInitialized",
      );
    });

    it("publicSaleStarted: should return false, since block.timestamp < publicSaleStartTime", async () => {
      // should be false
      expect(await pioneerToken.publicSaleStarted()).to.be.false;
    });

    it("publicPurchase: should revert with '!start' message since public sale hasn't started", async () => {
      // get public sale price
      const publicSalePricePerToken = await pioneerToken.publicTokenUnitPrice();

      // should rever with "!start"
      await expect(
        pioneerToken.publicPurchase(AMOUNT_TO_PURCHASE, { value: AMOUNT_TO_PURCHASE.mul(publicSalePricePerToken) }),
      ).to.be.revertedWith("!start");
    });

    it("initializeSale: should revert with message 'Merkle root already set' if already initialized", async () => {
      // should revert with "Merkle root already set"
      await expect(
        pioneerToken.connect(admin).initializeSale(whitelistedMerkleTree.root, PUBLIC_SALE_OFFSET),
      ).to.be.revertedWith("Merkle root already set");
    });

    it("whitelistPurchase: should emit 'WhitelistPurchase' event when successful", async () => {
      // purchase only one token per accouns
      for (let i = 0; i < whitelistedWallets.length; i++) {
        await expect(
          pioneerToken
            .connect(whitelistedWallets[i])
            .whitelistPurchase(AMOUNT_TO_PURCHASE, whitelistedMerkleTree.proofsFromIndex(i), {
              value: WHITELIST_TOKEN_UNIT_PRICE.mul(AMOUNT_TO_PURCHASE),
            }),
        )
          .to.emit(pioneerToken, "WhitelistPurchase")
          .withArgs(await whitelistedWallets[i].getAddress(), AMOUNT_TO_PURCHASE);
        let balanceSum = BigNumber.from(0);
        expect(await pioneerToken.userWhitelistPurchasedAmount(whitelistedWallets[i].getAddress())).to.be.equal(
          AMOUNT_TO_PURCHASE,
        );
        for (let id = Pioneer.BRONZE; id <= Pioneer.GOLD; id++)
          balanceSum = balanceSum.add(await pioneerToken.balanceOf(whitelistedWallets[i].getAddress(), id));
        expect(balanceSum).to.be.equal(BigNumber.from(1));
      }
    });

    it("whitelistPurchase: should revert with '!root' if caller is not authorized", async () => {
      // should revert with "!root" message
      await expect(
        pioneerToken.whitelistPurchase(AMOUNT_TO_PURCHASE, whitelistedMerkleTree.proofsFromIndex(0), {
          value: WHITELIST_TOKEN_UNIT_PRICE.mul(AMOUNT_TO_PURCHASE),
        }),
      ).to.be.revertedWith("!root");
    });

    it("whitelistPurchase: should revert with 'Maximum amount purchased' message if user purchase more than WHITELIST_PURCHASE_PER_ADDRESS", async () => {
      // get user wallet and merkle proof
      const userWallet = whitelistedWallets[0];
      const userProof = whitelistedMerkleTree.proofsFromIndex(0);

      // get exceding amount
      const excedingAmount = (await pioneerToken.WHITELIST_PURCHASE_PER_ADDRESS())
        .sub(await pioneerToken.userWhitelistPurchasedAmount(userWallet.getAddress()))
        .add(1);

      // should revert with "Maximum amount purchased" message
      await expect(pioneerToken.connect(userWallet).whitelistPurchase(excedingAmount, userProof)).to.be.revertedWith(
        "Maximum amount purchased",
      );
    });

    describe("Public sale starts", () => {
      let buyer: Signer;
      let purchasableLimit: BigNumber;
      let publicSalePricePerToken: BigNumber;

      before(async () => {
        // get public sale start time
        const publicSaleStartTime = await pioneerToken.publicSaleStartTime();

        // Set next block timestamp to be the public sale start timestamp
        await setBlockTimestamp(publicSaleStartTime.toNumber());

        // get a signer to purchase NFTs
        [buyer] = (await ethers.getSigners()).slice(8);

        // get purchasable limit
        purchasableLimit = (await pioneerToken.PURCHASABLE_SUPPLY()).sub(await pioneerToken.purchasedAmount());

        // get public sale price per token
        publicSalePricePerToken = await pioneerToken.publicTokenUnitPrice();
      });

      it("publicPurchase: reverts with '!purchase' message if user try to purchase the exceding PURCHASABLE_SUPPLY limit", async () => {
        // get exceding purchase amount
        const excedingAmount = purchasableLimit.add(1);

        // should revert with "!purchase"
        await expect(
          pioneerToken
            .connect(buyer)
            .publicPurchase(excedingAmount, { value: excedingAmount.mul(publicSalePricePerToken) }),
        ).to.be.revertedWith("!purchase");
      });

      it("publicPurchase: reverts with 'Not enough ethers' message if user doesn't send enought ethers to buy tokens", async () => {
        // get insufficient ethers value
        const insufficientValue = BigNumber.from(1).mul(publicSalePricePerToken).sub(1);

        // should revert with "Not enough ethers"
        await expect(
          pioneerToken.connect(buyer).publicPurchase(BigNumber.from(1), { value: insufficientValue }),
        ).to.be.revertedWith("Not enough ethers");
      });

      it("publicPurchase: purchase all supply with surplus payment", async () => {
        // get total price
        const totalPrice = purchasableLimit.mul(publicSalePricePerToken);

        // get surplus
        const surplus = randomUint256().mod((await buyer.getBalance()).sub(totalPrice));

        // should emit "PioneerClaim"
        const pioneerBalanceBefore = await ethers.provider.getBalance(pioneerToken.address);
        await expect(
          pioneerToken.connect(buyer).publicPurchase(purchasableLimit, { value: totalPrice.add(surplus) }),
        ).to.emit(pioneerToken, "PioneerClaim");

        // check pioneerNFT balance
        const pioneerBalanceAfter = await ethers.provider.getBalance(pioneerToken.address);
        expect(pioneerBalanceAfter.sub(pioneerBalanceBefore)).to.be.equal(totalPrice);
        let totalBalance = BigNumber.from(0);
        for (let id = Pioneer.BRONZE; id <= Pioneer.GOLD; id++)
          totalBalance = totalBalance.add(await pioneerToken.balanceOf(buyer.getAddress(), id));
        expect(totalBalance).to.be.equal(purchasableLimit);
      });

      it("whitelistPurchase: reverts with '!purchase' if amount excessed PURCHASABLE_AMOUNT", async () => {
        // should revert with "!purchase"
        await expect(
          pioneerToken
            .connect(whitelistedWallets[0])
            .whitelistPurchase(BigNumber.from(1), whitelistedMerkleTree.proofsFromIndex(0), {
              value: BigNumber.from(1).mul(WHITELIST_TOKEN_UNIT_PRICE),
            }),
        ).to.be.revertedWith("!purchase");
      });

      it("withdraw: should revert if caller is not the admin", async () => {
        // should revert with "!admin" message
        await expect(pioneerToken.withdraw(deployer.getAddress())).to.revertedWith("!admin");
      });

      it("withdraw: should revert with 'Failed sending ethers' message if unable to send ethers", async () => {
        // deploy EthBlockerMock contract
        const ethBlockerMockFactory = <EthBlockerMock__factory>await ethers.getContractFactory("EthBlockerMock");
        const ethBlockerMock: EthBlockerMock = await ethBlockerMockFactory.connect(admin).deploy();

        // should revert with "Failed sending ethers"
        await expect(pioneerToken.connect(admin).withdraw(ethBlockerMock.address)).to.be.revertedWith(
          "Failed sending ethers",
        );
      });

      it("withdraw: should emit Withdrawal", async () => {
        // get pioneer ether balance
        const pioneerEtherBalance = await ethers.provider.getBalance(pioneerToken.address);

        // send to deployer
        const deployerBalanceBefore = await deployer.getBalance();
        await expect(pioneerToken.connect(admin).withdraw(deployer.getAddress()))
          .to.emit(pioneerToken, "Withdrawal")
          .withArgs(await admin.getAddress(), await deployer.getAddress(), pioneerEtherBalance);

        // check balance
        const deployerBalanceAfter = await deployer.getBalance();
        expect(deployerBalanceAfter.sub(deployerBalanceBefore)).to.be.equal(pioneerEtherBalance);
      });
    });

    describe("Airdrop claims", () => {
      let AirdropSigners: Signer[];
      let airdropTree: AirdropTree;
      let maximumAirdrops: BigNumber;

      before(async () => {
        // get airdrop signers
        AirdropSigners = (await ethers.getSigners()).slice(9, 13);

        // get maximum airdrops and tokens per address
        maximumAirdrops = await pioneerToken.AIRDROP_MAX_CLAIMS();
        const tokensPerAddress = maximumAirdrops.div(AirdropSigners.length);
        const airdropList: Airdrop[] = [];
        for (const signer of AirdropSigners) {
          airdropList.push({ account: await signer.getAddress(), amount: tokensPerAddress });
        }

        // build AirdropTree
        airdropTree = new AirdropTree(airdropList);
      });

      it("setAirdropRoot: reverts with '!admin' if caller is not the admin", async () => {
        // should revert with "!admin" message
        await expect(pioneerToken.setAirdropRoot(airdropTree.root)).to.be.revertedWith("!admin");
      });

      it("setAirdropRoot: should emit 'AirdropMerkleRootSet' if successful", async () => {
        // should emit "AirdropMerkleRootSet"
        await expect(pioneerToken.connect(admin).setAirdropRoot(airdropTree.root)).to.emit(
          pioneerToken,
          "AirdropMerkleRootSet",
        );
      });

      it("claimAirdrop: reverts with '!merkleRoot' message if proof is invalid", async () => {
        // should revert with "!merkleRoot"
        await expect(
          pioneerToken
            .connect(AirdropSigners[0])
            .claimAirdrop(<BigNumberish>airdropTree.getAmountAt(0), airdropTree.proofsFromIndex(1)),
        ).to.be.revertedWith("!merkleRoot");
      });

      it("claimAirdrop: should emit 'AirdropClaim' when successful", async () => {
        // should emit "AirdropClaim"
        await expect(
          pioneerToken
            .connect(AirdropSigners[0])
            .claimAirdrop(<BigNumberish>airdropTree.getAmountAt(0), airdropTree.proofsFromIndex(0)),
        )
          .to.emit(pioneerToken, "AirdropClaim")
          .withArgs(airdropTree.getAccountAt(0), airdropTree.getAmountAt(0));
      });

      it("claimAirdrop: should revert with message '!userNonce' when a whitelisted user tries to claim again", async () => {
        // should revert with "!userNonce" message
        await expect(
          pioneerToken
            .connect(AirdropSigners[0])
            .claimAirdrop(<BigNumberish>airdropTree.getAmountAt(0), airdropTree.proofsFromIndex(0)),
        ).to.be.revertedWith("!userNonce");
      });

      it("claimAirdrop: should revert with '!airdrop' message if airdrop tokens are depleted", async () => {
        // claim all airdrop tokens
        for (let i = 1; i < airdropTree.airdropLength; i++) {
          await pioneerToken
            .connect(AirdropSigners[i])
            .claimAirdrop(<BigNumberish>airdropTree.getAmountAt(i), airdropTree.proofsFromIndex(i));
        }

        // should revert with "!airdrop" message
        // try to claim additional airdrop with user at index 0
        // max airdrop check comes before nonce check
        await expect(
          pioneerToken
            .connect(AirdropSigners[0])
            .claimAirdrop(<BigNumberish>airdropTree.getAmountAt(0), airdropTree.proofsFromIndex(0)),
        ).to.be.revertedWith("!airdrop");
      });

      it("setAirdropRoot: should revert with '!airdrop' message when airdrop is depleted", async () => {
        // should revert with "!airdrop" message
        await expect(pioneerToken.connect(admin).setAirdropRoot(airdropTree.root)).to.be.revertedWith("!airdrop");
      });
    });
  });
});
