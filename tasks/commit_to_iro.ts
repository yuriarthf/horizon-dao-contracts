// commit_to_iro.ts: Commit to an IRO

// Import task tooling
import { task } from "hardhat/config";

enum Status {
  PENDING,
  ONGOING,
  SUCCESS,
  FAIL,
}

task("iro:commit", "Commit to an IRO")
  .addParam("id", "ID of the IRO.")
  .addParam("amount", "Amount of tokens to purchase")
  .addOptionalParam("contract", "Address of the IRO contract.")
  .setAction(async (taskArgs, hre) => {
    // get signer
    const [signer] = await hre.ethers.getSigners();

    // instantiate IRO contract
    const iroContract = await hre.ethers.getContractAt(
      "InitialRealEstateOffering",
      taskArgs.contract ?? (await hre.deployments.get("InitialRealEstateOffering_Proxy")).address,
      signer,
    );

    // check status
    const status = await iroContract.getStatus(taskArgs.id);
    if (status != Status.ONGOING) throw new Error("IRO not active");

    // get currency
    const { currency: currencyAddress } = await iroContract.getIRO(taskArgs.id);
    const currencyContract = await hre.ethers.getContractAt("IERC20Extended", currencyAddress, signer);

    // get total price
    const totalPrice = await iroContract.price(taskArgs.id, taskArgs.amount);

    // approve currency transfer
    let tx = await currencyContract.approve(iroContract.address, totalPrice);
    await tx.wait();

    // commit to IRO
    tx = await iroContract.commit(taskArgs.id, taskArgs.amount);
    await tx.wait();

    console.log(`Commited for ${taskArgs.amount} tokens on IRO #${taskArgs.id}`);
  });
