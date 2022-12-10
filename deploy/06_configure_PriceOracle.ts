// 06_configure_PriceOracle.ts: Configure PriceOracle contract

// Import HRE type
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Import types
import { DeployFunction } from "hardhat-deploy/types";
import { PriceOracle } from "../typechain-types";

// Import deployment args
import { getDeployer, horizonMultisig, priceOracleFeeds } from "./utils/deployment_args";

async function initPriceFeeds(priceOracle: PriceOracle, feedsForNetwork: ReturnType<typeof priceOracleFeeds>) {
  const feeds = Object.values(<{ [s: string]: string[] }>feedsForNetwork);
  const txs = [];
  for (const feed of feeds) {
    txs.push((await priceOracle.setAggregator(feed[0], feed[1], feed[2])).wait());
  }

  await Promise.all(txs);
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // get Price Oracle proxy address and ABI
  const { address: priceOracleProxyAddress, abi: priceOracleAbi } = await hre.deployments.get("PriceOracle");

  // add some feeds
  const priceOracleOwner = await getDeployer();
  const priceOracle = <PriceOracle>new hre.ethers.Contract(priceOracleProxyAddress, priceOracleAbi);
  await initPriceFeeds(priceOracle.connect(priceOracleOwner), priceOracleFeeds(hre.network.name));

  // send ownership to Horizon Multisig
  await priceOracle.connect(priceOracleOwner).transferOwnership(horizonMultisig[hre.network.name]);
};
func.tags = ["config", "PriceOracle", "RealEstate", "06"];
export default func;
