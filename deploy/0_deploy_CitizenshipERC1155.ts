// 0_deploy_CitizenshipERC1155.ts: Deploy all contracts

// Import HRE type
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Import type for the deploy function
import { DeployFunction } from "hardhat-deploy/types";

// Import constructor arguments for the contracts
import { citizenshipErc1155Args, silverWhitelist, goldWhitelist } from "./utils/deployment_args";

// Import citizenship merkle tree
import { CitizenshipTree } from "../test/token/utils/citizenship_tree";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // get necessary hardhat-deploy functions
  const { deploy } = hre.deployments;

  // get deployer address
  const { deployer } = await hre.getNamedAccounts();

  // deploy SKY token
  let deployResult;
  const constructorArgs = citizenshipErc1155Args(hre.network.name);
  if (process.env.CONFIG_CITIZENSHIP_CONTRACT) {
    constructorArgs["admin"] = deployer;
    deployResult = await deploy("CitizenshipERC1155", {
      from: deployer,
      args: Object.values(constructorArgs),
      log: true,
    });

    // get deployed contract
    const citizenshipNft = await hre.ethers.getContractAt("CitizenshipERC1155", deployResult.address);

    // Build merkle trees
    const silverMerkleTree = new CitizenshipTree(silverWhitelist);
    const goldMerkleTree = new CitizenshipTree(goldWhitelist);

    // Set merkle roots
    await citizenshipNft.setSilverMerkleRoot(silverMerkleTree.root);
    await citizenshipNft.setGoldMerkleRoot(goldMerkleTree.root);

    // Transfer admin to multisig
    await citizenshipNft.setAdmin(citizenshipErc1155Args(hre.network.name).admin);
  } else {
    deployResult = await deploy("CitizenshipERC1155", {
      from: deployer,
      args: Object.values(constructorArgs),
      log: true,
    });
  }

  if (deployResult.newlyDeployed) {
    // Wait 5 confirmations
    await hre.ethers.provider.waitForTransaction(<string>deployResult.transactionHash, 5);

    // Verify contract
    await hre.run("verify:verify", {
      address: deployResult.address,
      constructorArguments: Object.values(constructorArgs),
    });
  }
};
func.tags = ["deploy", "citizenship"];
export default func;
