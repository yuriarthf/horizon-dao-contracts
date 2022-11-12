// Vesting.test.ts: Unit tests for Vesting contract

// Solidity extension for chai
import { solidity } from "ethereum-waffle";

// Use Chai for testing
import chai from "chai";
import { expect } from "chai";
// Setup chai plugins
chai.use(solidity);

// Import contract types
import type {
  ERC20PermitMock,
  VoteEscrowMock,
  Vesting,
  ERC20PermitMock__factory,
  NonERC165ERC20PermitMock__factory,
  VoteEscrowMock__factory,
  Vesting__factory,
} from "../../typechain-types";

// HardhatRuntimeEnvironment
import { ethers } from "hardhat";

// Get BigNumber
import { Signer } from "@ethersproject/abstract-signer";

describe("Vesting Unit Tests", () => {
  let erc20Mock: ERC20PermitMock;
  let voteEscrowMock: VoteEscrowMock;
  let vesting: Vesting;
  let owner: Signer;
  let user: Signer;

  const NAME = "test";
  const SYMBOL = "TEST";

  before(async () => {
    // get signers
    [owner, user] = await ethers.getSigners();

    // deploy ERC20PermitMock
    const erc20MockFactory = <ERC20PermitMock__factory>await ethers.getContractFactory("ERC20PermitMock");
    erc20Mock = await erc20MockFactory.connect(owner).deploy(NAME, SYMBOL);

    // deploy VoteEscrowMock
    const voteEscrowMockFactory = <VoteEscrowMock__factory>await ethers.getContractFactory("VoteEscrowMock");
    voteEscrowMock = await voteEscrowMockFactory.connect(owner).deploy(erc20Mock.address);

    // deploy Vesting
    const vestingFactory = <Vesting__factory>await ethers.getContractFactory("Vesting");
    vesting = await vestingFactory.connect(owner).deploy(erc20Mock.address);
  });

  it("constructor: reverts with 'Underlying should be IERC20 compatible' if underlying does not implement IERC20", async () => {
    // deploy ERC20 without with mocked ERC165
    const nonErc165Erc20MockFactory = <NonERC165ERC20PermitMock__factory>(
      await ethers.getContractFactory("NonERC165ERC20PermitMock")
    );
    const nonErc165Erc20Mock = await nonErc165Erc20MockFactory.connect(owner).deploy(NAME, SYMBOL);

    // should revert with "Underlying should be IERC20 compatible" message
    const vestingFactory = <Vesting__factory>await ethers.getContractFactory("Vesting");
    await expect(vestingFactory.connect(owner).deploy(nonErc165Erc20Mock.address)).to.be.revertedWith(
      "Underlying should be IERC20 compatible",
    );
  });

  it("TODO", () => {
    voteEscrowMock;
    vesting;
    user;
  });
});
