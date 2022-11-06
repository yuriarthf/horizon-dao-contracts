// pioneer_generate_pioneer_tree.ts:

// fs and path for outputting results
import fs from "fs";
import path from "path";

// Import task tooling
import { task } from "hardhat/config";

// Import types
import { Address } from "../test/types";

// Import PioneerTree
import { PioneerTree } from "../test/token/utils/pioneer_tree";

// Type for the accounts JSON input
type AccountList = Address[];

// Type for the proofs JSON output
interface PioneerProofs {
  [account: Address]: string[];
}

task("pioneer:generate-pioneer-tree", "Generate the PioneerTree and save proofs and root to a directory")
  .addOptionalParam(
    "accounts",
    "Path to JSON containing the list of accounts to be used to generate the pioneer tree (should follow AccountList type).",
  )
  .addOptionalParam("output", "Path to directory to output the proofs and root.")
  .addOptionalParam("preffix", "Preffix for output files.")
  .setAction(async (taskArgs) => {
    // get account list
    const accountList: AccountList = taskArgs.accounts
      ? require(taskArgs.accounts)
      : require("../data/input_data/pioneer_nft/pioneer_tree_private_accounts.json");

    // get output directory
    const outputDir = taskArgs.output ?? "data/output_data/pioneer_nft";

    // build PioneerTree
    const pioneerTree = new PioneerTree(accountList);

    // build PioneerProofs
    const pioneerProofs: PioneerProofs = {};
    for (let i = 0; i < accountList.length; i++) {
      pioneerProofs[accountList[i]] = pioneerTree.proofsFromIndex(i);
    }

    fs.writeFileSync(path.resolve(outputDir, taskArgs.preffix ?? "", "pioneer_root.txt"), pioneerTree.root);
    fs.writeFileSync(
      path.resolve(outputDir, taskArgs.preffix ?? "", "pioneer_proofs.json"),
      JSON.stringify(pioneerProofs),
    );
  });
