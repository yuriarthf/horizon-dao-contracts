// 3_deploy_PriceOracle.ts: Deploy PriceOracle

// Import HRE type
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Import types
import { DeployFunction } from "hardhat-deploy/types";

// Import deployment args
import { priceOracleArgs } from "./utils/deployment_args";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // get necessary hardhat-deploy functions
  const { deploy } = hre.deployments;

  // get deployer address
  const { deployer } = await hre.getNamedAccounts();

  // deploy PriceOracle
  const constructorArgs = Object.values(await priceOracleArgs());
  await deploy("PriceOracle", {
    contract: "PriceOracle",
    from: deployer,
    args: constructorArgs,
    log: true,
  });
};
func.tags = ["deploy", "PriceOracle", "RealEstate", "03"];
export default func;
