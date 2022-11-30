// 3_deploy_PriceOracle.ts: Deploy PriceOracle

// Import HRE type
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Import type for the deploy function
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // get necessary hardhat-deploy functions
  const { deploy } = hre.deployments;

  // get deployer address
  const { deployer } = await hre.getNamedAccounts();

  // deploy PriceOracle
  const deployResult = await deploy("PriceOracle", {
    contract: "PriceOracle",
    from: deployer,
    args: [],
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
func.tags = ["deploy", "PriceOracle"];
export default func;
