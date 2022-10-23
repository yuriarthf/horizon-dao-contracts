// 0_deploy_CitizenshipPromoERC1155.ts: Deploy all contracts

// Import HRE type
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Import type for the deploy function
import { DeployFunction } from "hardhat-deploy/types";

// Import constructor arguments for the contracts
import { citizenshipErc1155Args } from "./utils/deployment_args";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // get necessary hardhat-deploy functions
  const { deploy } = hre.deployments;

  // get deployer address
  const { deployer } = await hre.getNamedAccounts();

  // deploy SKY token
  await deploy("CitizenshipPromoERC1155", {
    from: deployer,
    args: Object.values(citizenshipErc1155Args(hre.network.name)),
    log: true,
  });
};
func.tags = ["deploy", "citizenship"];
export default func;
