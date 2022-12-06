// File contains deployment arguments for all contracts

import hre from "hardhat";

// Parse ethers
import { ethers } from "ethers";

// types
import { Address } from "../../test/types";

/*************** Common ***************/
// Deployment owner
export const deploymentOwner = async () => {
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
};

// USDT addresses
const usdt: { [network: string]: string } = {
  mainnet: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
  goerli: "0x509Ee0d083DdF8AC028f2a56731412edD63223B9",
};

// RealEstateNFT
const realEstateNft = async () => (await hre.deployments.get("RealEstateERC1155_Proxy")).address;

// Treasury
const treasury: { [network: string]: string } = {
  mainnet: "",
  goerli: "0x60d6b442292b33b745815EC90B7Ae5F315b4E777",
};

// RealEstateReserves
/*
const realEstateReserves: { [network: string]: string } = {
  mainnet: "",
  goerli: "",
};
*/

// Price Feed Registry
const priceFeedRegistry = async () => (await hre.deployments.get("PriceOracle")).address;

// Swap Router
const swapRouter: { [network: string]: string } = {
  mainnet: "",
  goerli: "0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506",
};

// RealEstateFunds
const weth: { [network: string]: string } = {
  mainnet: "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2",
  goerli: "0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6",
};

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
    admin: await deploymentOwner(), // Address with contract administration privileges
    owner: "0x39a242169BA3B28623E6d235A4Bdd46287d4bae3", // EOA to be used as OpenSea collection admin
    yieldCurrency: usdt[network], // Currency used to pay yields
  };
}

/*************** PriceOracle ***************/
export async function priceOracleArgs() {
  return {
    owner: await deploymentOwner(),
  };
}
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
    },
  }[network];
}

/*************** InitialRealEstateOffering ***************/
export async function initialRealEstateOfferingArgs(network: string) {
  return {
    owner: horizonMultisig[network],
    realEstateNft: await realEstateNft(),
    treasury: treasury[network],
    /* realEstateReserves: realEstateReserves[network], */
    realEstateReserves: "0x0000000000000000000000000000000000000000",
    baseCurrency: usdt[network],
    priceFeedRegistry: await priceFeedRegistry(),
    swapRouter: swapRouter[network],
    weth: weth[network],
  };
}
