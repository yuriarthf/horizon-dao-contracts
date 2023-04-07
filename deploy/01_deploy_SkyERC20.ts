// 01_deploy_SkyERC20.ts: Deploy SkyERC20

// Import HRE type
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Import type for the deploy function
import { DeployFunction } from "hardhat-deploy/types";

// Import constructor arguments for the contracts
import { skyErc20Args } from "./utils/deployment_args";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // get deployer address
  const { deployer } = await hre.getNamedAccounts();

  // deploy SKY token
  const constructorArgs = Object.values(skyErc20Args);
  const deployResult = await hre.deployments.deploy("SkyERC20", {
    contract: "SkyERC20",
    from: deployer,
    args: constructorArgs,
    log: true,
  });

  if (deployResult.newlyDeployed) {
    // Wait 5 confirmations
    await hre.ethers.provider.waitForTransaction(<string>deployResult.transactionHash, 5);

    // Verify contract
    await hre.run("verify", {
      address: deployResult.address,
      constructorArgsParams: constructorArgs,
    });
  }
};
func.tags = ["deploy", "SkyToken", "SKY", "01"];
export default func;
