// ERC20Permit.test.ts: Unit tests for PioneerERC1155 token

// Solidity extension for chai
import { solidity } from "ethereum-waffle";

// Use Chai for testing
import chai from "chai";
import { expect } from "chai";
// Setup chai plugins
chai.use(solidity);

// Import contract types
import type { ERC20PermitMock, ERC20PermitMock__factory } from "../../typechain-types";

// HardhatRuntimeEnvironment
import { ethers, network } from "hardhat";

// Get BigNumber
import { BigNumber } from "@ethersproject/bignumber";
import { Signer } from "@ethersproject/abstract-signer";

// Import EVM utils
import { now, setBlockTimestamp } from "../utils/evm_utils";

describe("ERC20Permit Unit tests", () => {
  let erc20Permit: ERC20PermitMock;
  let deployer: Signer;
  let user: Signer;

  const NAME = "Test";
  const SYMBOL = "TEST";

  before(async () => {
    // get signers
    [deployer, user] = await ethers.getSigners();

    // deploy contract
    const erc20PermitFactory = <ERC20PermitMock__factory>await ethers.getContractFactory("ERC20PermitMock");
    erc20Permit = await erc20PermitFactory.connect(deployer).deploy(NAME, SYMBOL);
  });

  it("supportsInterface: Supports IERC20 and IERC165", async () => {
    // Interface IDs
    const Ierc20InterfaceId = "0x36372b07";
    const Ierc165InterfaceId = "0x01ffc9a7";

    // Check if interfaces are supported
    expect(await erc20Permit.supportsInterface(Ierc20InterfaceId)).to.be.true;
    expect(await erc20Permit.supportsInterface(Ierc165InterfaceId)).to.be.true;
  });

  describe("Test permit", () => {
    let eip721Signature: string;
    let deadline: BigNumber;

    const TOKENS_TO_MINT = ethers.utils.parseEther("1000000");
    const PERMIT_VALIDITY = BigNumber.from("259200"); // 3 days

    beforeEach(async () => {
      // mint tokens to deployer
      await erc20Permit.freeMint(deployer.getAddress(), TOKENS_TO_MINT);

      // define domain
      const domain = {
        name: NAME,
        version: "1",
        chainId: network.config.chainId,
        verifyingContract: erc20Permit.address,
      };

      // define permit type
      const types = {
        Permit: [
          { name: "owner", type: "address" },
          { name: "spender", type: "address" },
          { name: "value", type: "uint256" },
          { name: "nonce", type: "uint256" },
          { name: "deadline", type: "uint256" },
        ],
      };

      // define permit value
      deadline = BigNumber.from(await now()).add(PERMIT_VALIDITY);
      const values = {
        owner: await deployer.getAddress(),
        spender: await user.getAddress(),
        value: TOKENS_TO_MINT,
        nonce: BigNumber.from(0),
        deadline,
      };

      // get signature
      eip721Signature = deployer._signTypedData(domain, types, values);
    });

    it("permit: reverts with 'ERC20Permit: deadline reached' if deadline has passed", async () => {
      // advance time
      await setBlockTimestamp(deadline.toNumber());

      // should revert with "ERC20Permit: deadline reached"
      await expect(
        erc20Permit
          .connect(user)
          .permit(deployer.getAddress(), user.getAddress(), TOKENS_TO_MINT, deadline, eip721Signature),
      ).to.be.revertedWith("ERC20Permit: deadline reached");
    });

    it("permit: reverts with 'ERC20Permit: invalid permit' message if permit owner differs from provided value", async () => {
      // should revert with "ERC20Permit: invalid permit"
      await expect(
        erc20Permit
          .connect(user)
          .permit(user.getAddress(), user.getAddress(), TOKENS_TO_MINT, deadline, eip721Signature),
      ).to.be.revertedWith("ERC20Permit: invalid permit");
    });

    it("permit: should emit 'Approval' when successful and user should be able to move funds", async () => {
      // should emit "Approval"
      await expect(
        erc20Permit
          .connect(user)
          .permit(deployer.getAddress(), user.getAddress(), TOKENS_TO_MINT, deadline, eip721Signature),
      )
        .to.emit(erc20Permit, "Approval")
        .withArgs(await deployer.getAddress(), await user.getAddress(), TOKENS_TO_MINT);

      // should increase nonce
      expect(await erc20Permit.nonces(deployer.getAddress())).to.be.equal(BigNumber.from(1));

      // user should be able to move funds
      await expect(
        await erc20Permit.connect(user).transferFrom(deployer.getAddress(), user.getAddress(), TOKENS_TO_MINT),
      )
        .to.emit(erc20Permit, "Transfer")
        .withArgs(await deployer.getAddress(), await user.getAddress(), TOKENS_TO_MINT);

      // check user balance
      expect(await erc20Permit.balanceOf(user.getAddress())).to.be.equal(TOKENS_TO_MINT);
    });
  });
});
