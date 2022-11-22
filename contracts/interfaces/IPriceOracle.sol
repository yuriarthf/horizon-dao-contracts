// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

interface IPriceOracle {
    /// @notice Get Price Aggregator address
    /// @param _base Base currency address
    /// @param _quote Quote currency address
    /// @return Chainlink aggregator for base/quote
    function priceAggregator(address _base, address _quote) external view returns (AggregatorV3Interface);

    /// @dev Set a new chainlink price aggregator
    /// @param _base Base currency address
    /// @param _quote Quote currency address
    function setAggregator(address _base, address _quote, address _aggregator) external;

    /// @notice Get price of `_base` in `quote`
    /// @param _base Base currency address
    /// @param _quote Quote currency address
    /// @return basePrice Base price in quote
    function getPrice(address _base, address _quote) external view returns (uint256 basePrice);
}
