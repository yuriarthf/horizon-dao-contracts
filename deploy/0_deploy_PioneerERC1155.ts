// 0_deploy_PioneerERC1155.ts: Deploy PioneerERC1155

// Import HRE type
import { HardhatRuntimeEnvironment } from "hardhat/types";

// Import type for the deploy function
import { DeployFunction } from "hardhat-deploy/types";

// Import constructor arguments for the contracts
import { pioneerErc1155Args, privateClaim, whitelistSale, publicSaleOffset } from "./utils/deployment_args";

// Import pioneer merkle tree
import { PioneerTree } from "../test/token/utils/pioneer_tree";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  // get necessary hardhat-deploy functions
  const { deploy } = hre.deployments;

  // get deployer address
  const { deployer } = await hre.getNamedAccounts();

  // deploy SKY token
  let deployResult;
  const constructorArgs = pioneerErc1155Args(hre.network.name);
  if (process.env.CONFIG_pioneer_CONTRACT) {
    constructorArgs["admin"] = deployer;
    deployResult = await deploy("pioneerERC1155", {
      from: deployer,
      args: Object.values(constructorArgs),
      log: true,
    });

    // get deployed contract
    const pioneerNft = await hre.ethers.getContractAt("PioneerERC1155", deployResult.address);

    // Build merkle trees
    const privateMerkleTree = new PioneerTree(privateClaim);
    const whitelistedMerkleTree = new PioneerTree(whitelistSale);

    // Set merkle roots
    await pioneerNft.setPrivateRoot(privateMerkleTree.root);
    await pioneerNft.initializeSale(whitelistedMerkleTree.root, publicSaleOffset);

    // Transfer admin to multisig
    await pioneerNft.setAdmin(pioneerErc1155Args(hre.network.name).admin);
  } else {
    deployResult = await deploy("PioneerERC1155", {
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
func.tags = ["deploy", "PioneerNFT"];
export default func;
