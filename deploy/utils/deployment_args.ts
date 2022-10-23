// File contains deployment arguments for all contracts

// Parse ethers
import ethers from "ethers";

// Common args
const horizonMultisig: { [network: string]: string } = {
  mainnet: "",
  goerli: "0x63926E60619172FE58870BCeb057b3B437Fa62FC",
};

// CitizenshipERC1155
export function citizenshipErc1155Args(network: string) {
  return {
    imageUri: "", // Image base URI, will be suffixed by collection ID (should return the collection image)
    admin: horizonMultisig[network], // Collection admin address (HorizonDAO Multisig)
    owner: "", // OpenSea collection owner (Can edit collection page)
    tokenUnitPrice: ethers.utils.parseEther("0.25"), // Price in wei to purchase an unit of random citizenship NFT
    chances: [948, 47, 5], // Chances to acquire each of the citizenship collection NFTs for each amount purchased
  };
}

// SKYERC20
export const skyErc20Args = {
  admin: "", // HorizonDAO multisig wallet address
  numberOfEpochs: "", // Number of token releasing epochs (n)
  firstEpochStartTime: "", // Timestamp of when the first epoch will commence
  epochDurations: [], // Each of the epoch durations (the last epoch duration is infinite so n-1 values should be provided)
  rampValues: [], // How much the availableSupply will increase at each epoch start (n values)
};
