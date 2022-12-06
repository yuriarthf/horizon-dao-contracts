// 3_deploy_PriceOracle.ts: Deploy PriceOracle

// Import HRE type
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Import types
import { DeployFunction } from "hardhat-deploy/types";
import { PriceOracle } from "../typechain-types";

// Import deployment args
import { priceOracleArgs, priceOracleFeeds, horizonMultisig } from "./utils/deployment_args";

async function initPriceFeeds(priceOracle: PriceOracle, feedsForNetwork: ReturnType<typeof priceOracleFeeds>) {
  const feeds = Object.values(<{ [s: string]: string[] }>feedsForNetwork);
  const txs = [];
  for (const feed of feeds) {
    txs.push(await priceOracle.setAggregator(feed[0], feed[1], feed[2]));
  }
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // get necessary hardhat-deploy functions
  const { deploy } = hre.deployments;

  // get deployer address
  const { deployer } = await hre.getNamedAccounts();

  // deploy PriceOracle
  const constructorArgs = Object.values(await priceOracleArgs());
  const deployResult = await deploy("PriceOracle", {
    contract: "PriceOracle",
    from: deployer,
    args: constructorArgs,
    log: true,
  });

  // add some feeds
  const priceOracle = <PriceOracle>new hre.ethers.Contract(deployResult.address, deployResult.abi);
  await initPriceFeeds(priceOracle, priceOracleFeeds(hre.network.name));

  // send ownership to Horizon Multisig
  await priceOracle.transferOwnership(horizonMultisig[hre.network.name]);

  if (deployResult.newlyDeployed) {
    // Wait 5 confirmations
    await hre.ethers.provider.waitForTransaction(<string>deployResult.transactionHash, 5);

    // Verify contract
    console.log(constructorArgs);
    await hre.run("verify", {
      address: deployResult.address,
      constructorArgsParams: constructorArgs,
    });
  }
};
func.tags = ["deploy", "PriceOracle"];
export default func;
