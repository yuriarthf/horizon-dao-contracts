// 02_deploy_RealEstateERC1155.ts: Deploy RealEstateERC1155

// Import HRE type
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Import type for the deploy function
import { DeployFunction } from "hardhat-deploy/types";

// Import constructor arguments for the contracts
import { realEstateErc1155Args } from "./utils/deployment_args";

// Hardhat upgrades ERC1965
import ERC1965ProxyArtifact from "@openzeppelin/upgrades-core/artifacts/@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol/ERC1967Proxy.json";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // get deployer address
  const { deployer } = await hre.getNamedAccounts();

  // deploy InitialRealEstateOffering implementation
  await hre.deployments.deploy("RealEstateERC1155_Impl", {
    contract: "RealEstateERC1155",
    from: deployer,
    args: [],
    log: true,
  });

  // get init config
  const initConfig = await realEstateErc1155Args(hre.network.name);

  // deploy USDT Mock if not present in config
  if (!initConfig.yieldCurrency) {
    let deployment;
    try {
      deployment = await hre.deployments.get("USDT_Mock");
    } catch (err) {
      deployment = await hre.deployments.deploy("USDT_Mock", {
        contract: "USDTMock",
        from: deployer,
        args: [deployer], // TODO: Change to a configurable address
        log: true,
      });

      // Verify contract
      await hre.run("verify", {
        address: deployment.address,
        constructorArguments: [deployer],
      });
    }
    initConfig.yieldCurrency = deployment.address;
  }

  // deploy InitialRealEstateOffering proxy
  const constructorArgs = Object.values(initConfig);
  const deployment = await hre.deployments.get("RealEstateERC1155_Impl");
  const iface = new hre.ethers.utils.Interface(deployment.abi);
  const initData = iface.encodeFunctionData("initialize", constructorArgs);
  const deployResult = await hre.deployments.deploy("RealEstateERC1155_Proxy", {
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
func.tags = ["deploy", "RealEstateNFT", "reNFT", "RealEstate", "02"];
export default func;
