// 1_deploy.ts: Deploy all contracts

// Import HRE type
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Import type for the deploy function
import { DeployFunction } from "hardhat-deploy/types";

// Import constructor arguments for the contracts
import { skyErc20Args } from "./utils/deployment_args";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // get necessary hardhat-deploy functions
  const { deploy } = hre.deployments;

  // get deployer address
  const { deployer } = await hre.getNamedAccounts();

  // deploy SKY token
  await deploy("SkyERC20", {
    from: deployer,
    args: Object.values(skyErc20Args),
    log: true,
  });
};
func.tags = ["deploy"];
export default func;
