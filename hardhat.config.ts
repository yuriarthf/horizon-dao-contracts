import path from "path";

// brings ethers.js to Hardhat
// https://hardhat.org/hardhat-runner/plugins/nomiclabs-hardhat-ethers
import "@nomiclabs/hardhat-ethers";

// enable etherscan integration
// https://hardhat.org/plugins/nomiclabs-hardhat-etherscan.html
import "@nomiclabs/hardhat-etherscan";

// build smart contract tests using Waffle in Hardhat
// https://www.npmjs.com/package/@nomiclabs/hardhat-waffle
import "@nomiclabs/hardhat-waffle";

// generate types for smart contracts (solidity)
// https://www.npmjs.com/package/@typechain/hardhat
import "@typechain/hardhat";

// compile Solidity sources directly from NPM dependencies
// https://github.com/ItsNickBarry/hardhat-dependency-compiler
import "hardhat-dependency-compiler";

// adds a mechanism to deploy contracts to any network,
// keeping track of them and replicating the same environment for testing
// https://www.npmjs.com/package/hardhat-deploy
import "hardhat-deploy";

// enable hardhat-gas-reporter
// https://hardhat.org/plugins/hardhat-gas-reporter.html
import "hardhat-gas-reporter";

// enable Solidity-coverage
// https://github.com/sc-forks/solidity-coverage
import "solidity-coverage";

// add all hardhat tasks
import "./tasks/index";

/**
 * default Hardhat configuration which uses account mnemonic to derive accounts
 * script expects following environment variables to be set:
 *   - P_KEY1 – mainnet private key, should start with 0x
 *     or
 *   - MNEMONIC1 – mainnet mnemonic, 12 words
 *
 *   - P_KEY5 – goerli private key, should start with 0x
 *     or
 *   - MNEMONIC5 – goerli mnemonic, 12 words
 *
 *   - ALCHEMY_KEY – Alchemy API key
 *     or
 *   - INFURA_KEY – Infura API key (Project ID)
 *
 *   - ETHERSCAN_KEY – Etherscan API key
 */

// Loads env variables from .env file
import { config as dotenvConfig } from "dotenv";
const dotenvConfigPath: string = process.env.DOTENV_CONFIG_PATH || "./.env";
dotenvConfig({ path: path.resolve(__dirname, dotenvConfigPath) });

// https://hardhat.org/hardhat-runner/docs/config
import { HardhatUserConfig } from "hardhat/config";
// verify environment setup, display warning if required, replace missing values with fakes
const FAKE_MNEMONIC = "test test test test test test test test test test test junk";
if (!process.env.MNEMONIC1 && !process.env.P_KEY1) {
  console.warn("neither MNEMONIC1 nor P_KEY1 is not set. Mainnet deployments won't be available");
  process.env.MNEMONIC1 = FAKE_MNEMONIC;
} else if (process.env.P_KEY1 && !process.env.P_KEY1.startsWith("0x")) {
  console.warn("P_KEY1 doesn't start with 0x. Appended 0x");
  process.env.P_KEY1 = "0x" + process.env.P_KEY1;
}
if (!process.env.MNEMONIC5 && !process.env.P_KEY5) {
  console.warn("neither MNEMONIC5 nor P_KEY5 is not set. Goerli deployments won't be available");
  process.env.MNEMONIC5 = FAKE_MNEMONIC;
} else if (process.env.P_KEY5 && !process.env.P_KEY5.startsWith("0x")) {
  console.warn("P_KEY5 doesn't start with 0x. Appended 0x");
  process.env.P_KEY5 = "0x" + process.env.P_KEY5;
}
if (!process.env.INFURA_KEY && !process.env.ALCHEMY_KEY) {
  console.warn("neither INFURA_KEY nor ALCHEMY_KEY is not set. Deployments may not be available");
  process.env.INFURA_KEY = "";
  process.env.ALCHEMY_KEY = "";
}
if (!process.env.ETHERSCAN_KEY) {
  console.warn("ETHERSCAN_KEY is not set. Deployed smart contract code verification won't be available");
  process.env.ETHERSCAN_KEY = "";
}

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    // https://hardhat.org/hardhat-network/
    hardhat: {
      // set networkId to 0xeeeb04de as for all local networks
      chainId: 0xeeeb04de,
      // set the gas price to one for convenient tx costs calculations in tests
      // gasPrice: 1,
      // London hard fork fix: impossible to set gas price lower than baseFeePerGas (875,000,000)
      initialBaseFeePerGas: 0,
      accounts: {
        count: 35,
      },
      /*
			forking: {
				url: "https://mainnet.infura.io/v3/" + process.env.INFURA_KEY, // create a key: https://infura.io/
				enabled: !!(process.env.HARDHAT_FORK),
			},
*/
    },
    // https://etherscan.io/
    mainnet: {
      url: get_endpoint_url("mainnet"),
      accounts: get_accounts(process.env.P_KEY1, process.env.MNEMONIC1),
    },
    // https://goerli.etherscan.io/
    goerli: {
      url: get_endpoint_url("goerli"),
      accounts: get_accounts(process.env.P_KEY5, process.env.MNEMONIC5),
    },
  },

  // Configure Solidity compiler
  solidity: {
    // https://hardhat.org/guides/compile-contracts.html
    compilers: [
      {
        // project main compiler version
        version: "0.8.17",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        // used for dependencies (boring-solidity)
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },

  // Set default mocha options here, use special reporters etc.
  mocha: {
    timeout: 100000000,
  },

  // Configure etherscan integration
  // https://hardhat.org/plugins/nomiclabs-hardhat-etherscan.html
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: process.env.ETHERSCAN_KEY,
  },

  // hardhat-gas-reporter will be disabled by default, use REPORT_GAS environment variable to enable it
  // https://hardhat.org/plugins/hardhat-gas-reporter.html
  gasReporter: {
    enabled: !!process.env.REPORT_GAS,
  },

  // compile Solidity sources directly from NPM dependencies
  // https://github.com/ItsNickBarry/hardhat-dependency-compiler
  dependencyCompiler: {
    paths: [
      // ERC1967 is used to deploy upgradeable contracts
      "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol",
    ],
  },

  // namedAccounts allows you to associate names to addresses and have them configured per chain
  // https://github.com/wighawag/hardhat-deploy#1-namedaccounts-ability-to-name-addresses
  namedAccounts: {
    // deployer account is always the accounut #0 derived from the mnemonic/private key
    deployer: {
      default: 0,
    },
    horizon_multisig: {
      mainnet: "",
      goerli: "0x63926E60619172FE58870BCeb057b3B437Fa62FC",
    },
  },
  typechain: {
    target: "ethers-v5",
    alwaysGenerateOverloads: false, // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
  },
};
export default config;

/**
 * Determines a JSON-RPC endpoint to use to connect to the node
 * based on the requested network name and environment variables set
 *
 * Tries to use custom RPC URL first (MAINNET_RPC_URL/ROPSTEN_RPC_URL/RINKEBY_RPC_URL/KOVAN_RPC_URL)
 * Tries to use alchemy RPC URL next (if ALCHEMY_KEY is set)
 * Fallbacks to infura RPC URL
 *
 * @param network_name one of mainnet/ropsten/rinkeby/kovan
 * @return JSON-RPC endpoint URL
 */
function get_endpoint_url(network_name: string) {
  // try custom RPC endpoint first (private node, quicknode, etc.)
  // create a quicknode key: https://www.quicknode.com/
  if (process.env.MAINNET_RPC_URL && network_name === "mainnet") {
    return process.env.MAINNET_RPC_URL;
  }
  if (process.env.GOERLI_RPC_URL && network_name === "goerli") {
    return process.env.GOERLI_RPC_URL;
  }

  // try the alchemy next
  // create a key: https://www.alchemy.com/
  if (process.env.ALCHEMY_KEY) {
    switch (network_name) {
      case "mainnet":
      case "goerli":
        return `https://eth-${network_name}.alchemyapi.io/v2/${process.env.ALCHEMY_KEY}`;
      default:
        throw Error("Invalid network");
    }
  }

  // fallback to infura
  // create a key: https://infura.io/
  switch (network_name) {
    case "mainnet":
    case "goerli":
      return `https://${network_name}.infura.io/v3/${process.env.INFURA_KEY};`;
    default:
      throw Error("Invalid network");
  }
}

/**
 * Depending on which of the inputs are available (private key or mnemonic),
 * constructs an account object for use in the hardhat config
 *
 * @param p_key account private key, export private key from mnemonic: https://metamask.io/
 * @param mnemonic 12 words mnemonic, create 12 words: https://metamask.io/
 * @return either [p_key] if p_key is defined, or {mnemonic} if mnemonic is defined
 */
function get_accounts(p_key?: string, mnemonic?: string) {
  return p_key ? [p_key] : mnemonic ? { mnemonic } : undefined;
}
