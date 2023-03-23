// File contains deployment arguments for all contracts

import hre from "hardhat";

// Parse ethers
import { ethers } from "ethers";

// types
import { Address } from "../../test/types";

/*************** Common ***************/
// Deployment owner
export const getDeployer = async () => {
  return (await hre.ethers.getSigners())[0];
};

// OpenSea collection owner
const openSeaCollectionOwner: { [network: string]: string } = {
  mainnet: "",
  goerli: "0x39a242169BA3B28623E6d235A4Bdd46287d4bae3",
};

// Horizon Multisig addresses
export const horizonMultisig: { [network: string]: string } = {
  mainnet: "",
  goerli: "0x63926E60619172FE58870BCeb057b3B437Fa62FC",
  mumbai: "0x39a242169BA3B28623E6d235A4Bdd46287d4bae3", // Gnosis doesn't support Mumbai
};

// USDT addresses
const usdt: { [network: string]: string } = {
  mainnet: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
  goerli: "0x509Ee0d083DdF8AC028f2a56731412edD63223B9",
  mumbai: "0x466DD1e48570FAA2E7f69B75139813e4F8EF75c2",
};

// USDC addresses
const usdc: { [network: string]: string } = {
  mainnet: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
  goerli: "0xD87Ba7A50B2E7E660f678A895E4B72E7CB4CCd9C",
};

// RealEstateNFT
const realEstateNft = async () => (await hre.deployments.get("RealEstateERC1155_Proxy")).address;

// Treasury
const treasury: { [network: string]: string } = {
  mainnet: "",
  goerli: "0x60d6b442292b33b745815EC90B7Ae5F315b4E777",
  mumbai: "0x39a242169BA3B28623E6d235A4Bdd46287d4bae3", // Gnosis doesn't support Mumbai
};

// RealEstateReserves
/*
const realEstateReserves: { [network: string]: string } = {
  mainnet: "",
  goerli: "",
};
*/

// Price Feed Registry
//const priceFeedRegistry = async () => (await hre.deployments.get("PriceOracle")).address;

// Swap Router
/*
const swapRouter: { [network: string]: string } = {
  mainnet: "",
  goerli: "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
};
*/

// whitelisted tokens
export function whitelistedTokens(network: string) {
  return {
    mainnet: {},
    goerli: {
      wbtc: "0xC04B0d3107736C32e19F1c62b2aF67BE61d63a05",
      eth: "0x0000000000000000000000000000000000000000",
      dai: "0x73967c6a0904aA032C103b4104747E88c566B1A2",
      usdc: usdc[network],
      usdt: usdt[network],
    },
  }[network];
}

/*************** PioneerERC1155 ***************/
// Constructor args
export function pioneerErc1155Args(network: string) {
  return {
    imageUri: "", // Image base URI, will be suffixed by collection ID (should return the collection image)
    admin: horizonMultisig[network], // Collection admin address (HorizonDAO Multisig)
    owner: openSeaCollectionOwner[network], // OpenSea collection owner (Can edit collection page)
    publicTokenUnitPrice: ethers.utils.parseEther("0.15"), // Price in wei to purchase an unit of random citizenship NFT (public sale)
    whitelistTokenUnitPrice: ethers.utils.parseEther("0.1"), // Price in wei to purchase an unit of random citizenship NFT (whitelisted sale)
    chances: [948, 47, 5], // Chances to acquire each of the citizenship collection NFTs for each amount purchased
  };
}

// Offset of which public sale will begin after initializing the sale
export const publicSaleOffset = 1209600; // 2 weeks

// Private claim addresses to be added to Merkle Tree
export const privateClaim: Address[] = [];

// Whitelisted sale addresses to be added to Merkle Tree
export const whitelistSale: Address[] = [];

/*************** SkyERC20 ***************/
// Constructor args
export const skyErc20Args = {
  admin: "", // HorizonDAO multisig wallet address
  numberOfEpochs: "", // Number of token releasing epochs (n)
  firstEpochStartTime: "", // Timestamp of when the first epoch will commence
  epochDurations: [], // Each of the epoch durations (the last epoch duration is infinite so n-1 values should be provided)
  rampValues: [], // How much the availableSupply will increase at each epoch start (n values)
};

/*************** RealEstateERC1155 ***************/
export async function realEstateErc1155Args(network: string) {
  return {
    baseUri: "", // Base URI for the offchain NFT metadata
    admin: (await getDeployer()).address, // Address with contract administration privileges
    owner: "0x39a242169BA3B28623E6d235A4Bdd46287d4bae3", // EOA to be used as OpenSea collection admin
    yieldCurrency: usdc[network], // Currency used to pay yields
  };
}

/*************** PriceOracle ***************/
export async function priceOracleArgs() {
  return {
    owner: (await getDeployer()).address,
  };
}

// Price Oracle feeds
export function priceOracleFeeds(network: string) {
  return {
    mainnet: {},
    goerli: {
      wbtc_usdt: [
        "0xC04B0d3107736C32e19F1c62b2aF67BE61d63a05",
        usdt[network],
        "0x779877A7B0D9E8603169DdbD7836e478b4624789",
      ],
      eth_usdt: [
        "0x0000000000000000000000000000000000000000",
        usdt[network],
        "0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e",
      ],
      dai_usdt: [
        "0x73967c6a0904aA032C103b4104747E88c566B1A2",
        usdt[network],
        "0x0d79df66BE487753B02D015Fb622DED7f0E9798d",
      ],
      usdc_usdt: [
        "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        usdt[network],
        "0xAb5c49580294Aff77670F839ea425f5b78ab3Ae7",
      ],
      wbtc_usdc: [
        "0xC04B0d3107736C32e19F1c62b2aF67BE61d63a05",
        usdc[network],
        "0x779877A7B0D9E8603169DdbD7836e478b4624789",
      ],
      eth_usdc: [
        "0x0000000000000000000000000000000000000000",
        usdc[network],
        "0xD4a33860578De61DBAbDc8BFdb98FD742fA7028e",
      ],
      dai_usdc: [
        "0x73967c6a0904aA032C103b4104747E88c566B1A2",
        usdc[network],
        "0x0d79df66BE487753B02D015Fb622DED7f0E9798d",
      ],
      usdc_usdc: [
        "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
        usdc[network],
        "0xAb5c49580294Aff77670F839ea425f5b78ab3Ae7",
      ],
    },
  }[network];
}

/*************** InitialRealEstateOffering ***************/
export async function initialRealEstateOfferingArgs(network: string) {
  return {
    owner: horizonMultisig[network],
    realEstateNft: await realEstateNft(),
    treasury: treasury[network],
    currency: usdt[network],
  };
}
