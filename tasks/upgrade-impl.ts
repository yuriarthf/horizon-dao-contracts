// upgrade-impl.ts: Upgrade a contract implementation
// Contract should be UUPS or Transparent Proxy

// Import task tooling
import { task } from "hardhat/config";

task("upgrade:impl", "Commit to an IRO")
  .addParam("proxy", "Address of the proxy contract")
  .addParam("impl", "New implementation name")
  .setAction(async (taskArgs, hre) => {
    // instantiate proxy contract
    const proxy = await hre.ethers.getContractAt("UUPSUpgradeable", taskArgs.proxy);

    // get new implementation contract factory
    const newImplDeployment = await hre.deployments.get(`${taskArgs.impl}_Impl_V2`);

    // upgrade proxy
    await proxy.upgradeTo(newImplDeployment.address);
  });
