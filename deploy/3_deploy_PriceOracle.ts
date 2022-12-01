// 3_deploy_PriceOracle.ts: Deploy PriceOracle

// Import HRE type
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Import type for the deploy function
import { DeployFunction } from "hardhat-deploy/types";

// Import constructor arguments for the contracts
import { priceOracleArgs } from "./utils/deployment_args";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // get necessary hardhat-deploy functions
  const { deploy } = hre.deployments;

  // get deployer address
  const { deployer } = await hre.getNamedAccounts();

  // deploy PriceOracle
  const constructorArgs = Object.values(priceOracleArgs(hre.network.name));
  const deployResult = await deploy("PriceOracle", {
    contract: "PriceOracle",
    from: deployer,
    args: constructorArgs,
    log: true,
  });

  if (deployResult.newlyDeployed) {
    // Wait 5 confirmations
    await hre.ethers.provider.waitForTransaction(<string>deployResult.transactionHash, 5);

    // Verify contract
    console.log(constructorArgs);
    await hre.run("verify", {
      address: deployResult.address,
      constructorArgsParams: constructorArgs,
    });
  }
};
func.tags = ["deploy", "PriceOracle"];
export default func;
