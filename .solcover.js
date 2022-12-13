module.exports = {
  skipFiles: ["mock", "test", "backup"],
  configureYulOptimizer: true,
  providerOptions: { options: { gasPrice: 0 } },
};
