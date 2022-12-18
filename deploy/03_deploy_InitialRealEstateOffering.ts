// 03_deploy_InitialRealEstateOffering.ts: Deploy InitialRealEstateOffering

// Import HRE type
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Import type for the deploy function
import { DeployFunction } from "hardhat-deploy/types";

// Import deployment args
import { initialRealEstateOfferingArgs } from "./utils/deployment_args";

// Hardhat upgrades ERC1965
import ERC1965ProxyArtifact from "@openzeppelin/upgrades-core/artifacts/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol/ERC1967Proxy.json";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // get deployer address
  const { deployer } = await hre.getNamedAccounts();

  // deploy InitialRealEstateOffering implementation
  await hre.deployments.deploy("InitialRealEstateOffering_Impl", {
    contract: "InitialRealEstateOffering",
    from: deployer,
    args: [],
    log: true,
  });

  // deploy InitialRealEstateOffering proxy
  const constructorArgs = Object.values(await initialRealEstateOfferingArgs(hre.network.name));
  const deployment = await hre.deployments.get("InitialRealEstateOffering_Impl");
  const iface = new hre.ethers.utils.Interface(deployment.abi);
  const initData = iface.encodeFunctionData("initialize", constructorArgs);
  const deployResult = await hre.deployments.deploy("InitialRealEstateOffering_Proxy", {
    contract: ERC1965ProxyArtifact,
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
    });
  }
};
func.tags = ["deploy", "InitialRealEstateOffering", "IRO", "RealEstate", "03"];
export default func;
