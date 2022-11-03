// 2_deploy_FractionalRealEstateERC1155.ts: Deploy FractionalRealEstateERC1155

// Import HRE type
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Import type for the deploy function
import { DeployFunction } from "hardhat-deploy/types";

// Import constructor arguments for the contracts
import { fractionalRealEstateErc1155Args } from "./utils/deployment_args";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // get necessary hardhat-deploy functions
  const { deploy } = hre.deployments;

  // get deployer address
  const { deployer } = await hre.getNamedAccounts();

  // deploy SKY token
  const constructorArgs = Object.values(fractionalRealEstateErc1155Args(hre.network.name));
  const deployResult = await deploy("FractionalRealEstateERC1155", {
    from: deployer,
    args: constructorArgs,
    log: true,
  });

  if (deployResult.newlyDeployed) {
    // Wait 5 confirmations
    await hre.ethers.provider.waitForTransaction(<string>deployResult.transactionHash, 5);

    // Verify contract
    await hre.run("verify:verify", {
      address: deployResult.address,
      constructorArguments: constructorArgs,
    });
  }
};
func.tags = ["deploy", "FractionRealEstateNFT", "reNFT"];
export default func;
