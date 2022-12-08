// 06_configure_PriceOracle.ts: Configure PriceOracle contract

// Import HRE type
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Import types
import { DeployFunction } from "hardhat-deploy/types";
import { InitialRealEstateOffering } from "../typechain-types";

// Import deployment args
import { getDeployer, horizonMultisig, whitelistedTokens } from "./utils/deployment_args";

async function initTokenWhitelist(iro: InitialRealEstateOffering, whitelist: ReturnType<typeof whitelistedTokens>) {
  const tokens = Object.values(<{ [s: string]: string }>whitelist);
  const txs = [];
  for (const token of tokens) {
    txs.push(await iro.whitelistCurrency(token, true));
  }
  await Promise.all(txs);
}

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // get IRO Proxy address and ABI
  const iroProxyAddress = (await hre.deployments.get("InitialRealEstateOffering_Proxy")).address;
  const iroAbi = (await hre.deployments.get("InitialRealEstateOffering_Impl")).address;

  // whitelist some tokens
  const iroOwner = await getDeployer();
  const iro = <InitialRealEstateOffering>new hre.ethers.Contract(iroProxyAddress, iroAbi);
  await initTokenWhitelist(iro.connect(iroOwner), whitelistedTokens(hre.network.name));

  // send ownership to Horizon Multisig
  await iro.connect(iroOwner).transferOwnership(horizonMultisig[hre.network.name]);
};
func.tags = ["config", "InitialRealEstateOffering", "IRO", "RealEstate", "07"];
export default func;
