// File contains deployment arguments for all contracts

// Parse ethers
import { ethers } from "ethers";

// types
import { Address } from "../../test/types";

/*************** Common ***************/
// Horizon Multisig addresses
const horizonMultisig: { [network: string]: string } = {
  mainnet: "",
  goerli: "0x63926E60619172FE58870BCeb057b3B437Fa62FC",
};

// USDT addresses
const usdt: { [network: string]: string } = {
  mainnet: "0xdAC17F958D2ee523a2206206994597C13D831ec7",
  goerli: "0x509Ee0d083DdF8AC028f2a56731412edD63223B9",
};

// RealEstateNFT
const realEstateNft: { [network: string]: string } = {
  mainnet: "",
  goerli: "",
};

// Treasury
const treasury: { [network: string]: string } = {
  mainnet: "",
  goerli: "",
};

// RealEstateFunds
/*
const realEstateFunds: { [network: string]: string } = {
  mainnet: "",
  goerli: "",
};
*/

// Price Feed Registry
const priceFeedRegistry: { [network: string]: string } = {
  mainnet: "",
  goerli: "",
};

// Swap Router
const swapRouter: { [network: string]: string } = {
  mainnet: "",
  goerli: "",
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
    owner: "0x39a242169BA3B28623E6d235A4Bdd46287d4bae3", // OpenSea collection owner (Can edit collection page)
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
export function realEstateErc1155Args(network: string) {
  return {
    baseUri: "", // Base URI for the offchain NFT metadata
    admin: horizonMultisig[network], // Address with contract administration privileges
    owner: "0x39a242169BA3B28623E6d235A4Bdd46287d4bae3", // EOA to be used as OpenSea collection admin
    yieldCurrency: usdt[network], // Currency used to pay yields
  };
}

/*************** InitialRealEstateOffering ***************/
export function initialRealEstateOfferingArgs(network: string) {
  return {
    realEstateNft: realEstateNft[network],
    treasury: treasury[network],
    /* realEstateFunds: realEstateFunds[network], */
    realEstateFunds: "0x0000000000000000000000000000000000000000",
    baseCurrency: usdt[network],
    priceFeedRegistry: priceFeedRegistry[network],
    swapRouter: swapRouter[network],
    weth: weth[network],
  };
}
