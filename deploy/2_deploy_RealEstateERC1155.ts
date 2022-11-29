// 2_deploy_RealEstateERC1155.ts: Deploy RealEstateERC1155

// Import HRE type
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Import type for the deploy function
import { DeployFunction } from "hardhat-deploy/types";

// Import constructor arguments for the contracts
import { realEstateErc1155Args } from "./utils/deployment_args";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // get necessary hardhat-upgrades functions
  const { deployProxy } = hre.upgrades;

  // deploy SKY token
  const constructorArgs = Object.values(realEstateErc1155Args(hre.network.name));
  const factory = await hre.ethers.getContractFactory("RealEstateERC1155");
  const contract = await deployProxy(factory, constructorArgs);

  // Wait 5 confirmations
  await hre.ethers.provider.waitForTransaction(<string>contract.transactionHash, 5);

  // Verify contract
  await hre.run("verify", {
    address: contract.address,
    constructorArguments: constructorArgs,
  });
};
func.tags = ["deploy", "RealEstateNFT", "reNFT"];
export default func;
