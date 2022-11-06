module.exports = {
  skipFiles: ["mock", "test"],
  configureYulOptimizer: true,
  providerOptions: { options: { gasPrice: 0 } },
};
