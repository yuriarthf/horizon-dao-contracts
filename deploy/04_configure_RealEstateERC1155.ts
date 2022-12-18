// 04_configure_RealEstateERC1155.ts: Configure RealEstateERC1155 contract

// Import HRE type
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Import type for the deploy function
import { DeployFunction } from "hardhat-deploy/types";

// Import deployment args
import { getDeployer, horizonMultisig } from "./utils/deployment_args";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // get temporary admin
  const realEstateAdmin = await getDeployer();

  // get IRO address
  const iroAddress = (await hre.deployments.get("InitialRealEstateOffering_Proxy")).address;

  // get Real Estate proxy address and ABI
  const realEstateProxyAddress = (await hre.deployments.get("RealEstateERC1155_Proxy")).address;
  const realEstateAbi = (await hre.deployments.get("RealEstateERC1155_Impl")).abi;

  // define IRO contract as the minter for reNFT
  const realEstateNft = new hre.ethers.Contract(realEstateProxyAddress, realEstateAbi);
  await realEstateNft.connect(realEstateAdmin).setMinter(iroAddress);

  // transfer admin role to Horizon Multisig
  await realEstateNft.connect(realEstateAdmin).setAdmin(horizonMultisig[hre.network.name]);
};
func.tags = ["config", "RealEstateNFT", "reNFT", "RealEstate", "04"];
export default func;
