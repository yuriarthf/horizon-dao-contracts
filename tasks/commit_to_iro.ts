// commit_to_iro.ts: Commit to an IRO

// Import task tooling
import { ethers } from "hardhat";
import { task } from "hardhat/config";

// Import types
import { Address } from "../test/types";

enum Status {
  PENDING,
  ONGOING,
  SUCCESS,
  FAIL,
}

task("iro:commit", "Commit to an IRO")
  .addParam("iroId", "ID of the IRO.")
  .addParam("amountToPurchase", "Amount of tokens to purchase")
  .addOptionalParam("contractAddress", "Address of the IRO contract.")
  .setAction(async (taskArgs, hre) => {
    // get signer
    const [signer] = await hre.ethers.getSigners();

    // instantiate IRO contract
    const iroContract = await hre.ethers.getContractAt(
      "InitialRealEstateOffering",
      taskArgs.contractAddress ?? (await hre.deployments.get("InitialRealEstateOffering_Proxy")).address,
      signer,
    );

    // check status
    const status = await iroContract.getStatus(taskArgs.iroId);
    if (status != Status.ONGOING) throw new Error("IRO not active");

    // get currency
    const { currency: currencyAddress } = await iroContract.getIRO(taskArgs.iroId);
    const currencyContract = await hre.ethers.getContractAt("IERC20Extended", currencyAddress, signer);

    // get total price
    const totalPrice = await iroContract.price(taskArgs.iroId, taskArgs.amountToPurchase);

    // approve currency transfer
    await currencyContract.approve(iroContract.address, totalPrice);

    // commit to IRO
    const tx = await iroContract.commit(taskArgs.iroId, taskArgs.amountToPurchase);
    await tx.wait();

    console.log(`Commited for ${taskArgs.amountToPurchase} tokens on IRO #${taskArgs.iroId}`);
  });
