// deploy-impl.ts: Deploy an implementation contract

// Import task tooling
import { task } from "hardhat/config";

task("deploy:impl", "Commit to an IRO")
  .addParam("impl", "New implementation name")
  .setAction(async (taskArgs, hre) => {
    // get deployer address
    const { deployer } = await hre.getNamedAccounts();

    // deploy InitialRealEstateOffering implementation
    await hre.deployments.deploy(`${taskArgs.impl}_Impl_V2`, {
      contract: taskArgs.impl,
      from: deployer,
      args: [],
      log: true,
    });
  });
