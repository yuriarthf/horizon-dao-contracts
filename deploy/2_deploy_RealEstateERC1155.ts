// 2_deploy_RealEstateERC1155.ts: Deploy RealEstateERC1155

// Import HRE type
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Import type for the deploy function
import { DeployFunction } from "hardhat-deploy/types";

// Import constructor arguments for the contracts
import { realEstateErc1155Args } from "./utils/deployment_args";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // get deployer address
  const { deployer } = await hre.getNamedAccounts();

  // deploy InitialRealEstateOffering implementation
  await hre.deployments.deploy("RealEstateERC1155_Impl", {
    contract: "InitialRealEstateOffering",
    from: deployer,
    args: [],
    log: true,
  });

  // deploy InitialRealEstateOffering proxy
  const constructorArgs = Object.values(realEstateErc1155Args(hre.network.name));
  const deployment = await hre.deployments.get("RealEstateERC1155_Impl");
  const iface = new hre.ethers.utils.Interface(deployment.abi);
  const initData = iface.encodeFunctionData("initialize", constructorArgs);
  const deployResult = await hre.deployments.deploy("RealEstateERC1155_Proxy", {
    contract: "ERC1967Proxy",
    from: deployer,
    args: [deployment.address, initData],
    log: true,
  });

  if (deployResult.newlyDeployed) {
    // Wait 5 confirmations
    await hre.ethers.provider.waitForTransaction(<string>deployResult.transactionHash, 5);

    // Verify contract
    await hre.run("verify", {
      address: deployResult.address,
      constructorArguments: constructorArgs,
    });
  }
};
func.tags = ["deploy", "RealEstateNFT", "reNFT"];
export default func;
