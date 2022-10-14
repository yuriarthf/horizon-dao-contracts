// File contains deployment arguments for all contracts

// SKYERC20
export const skyErc20Args = {
  admin: "", // HorizonDAO multisig wallet address
  numberOfEpochs: "", // Number of token releasing epochs (n)
  initialEpochStart: "", // Timestamp of when the first epoch will commence
  epochDurations: [], // Each of the epoch durations (the last epoch duration is infinit so n-1 values should be provided)
  rampValues: [], // How much the availableSupply will increase at each epoch start (n values)
};
