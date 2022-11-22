// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

import { AggregatorV3Interface } from "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import { IERC20Extended } from "../interfaces/IERC20Extended.sol";
import { IPriceOracle } from "../interfaces/IPriceOracle.sol";

/// @title Price Oracle
/// @author Horizon DAO (Yuri Fernandes)
/// @notice Uses Chainlink Price Aggregators to retrieve base price in quote (base/quote)
/// @dev Aggregator registration conventions:
///		- For stablecoins 1:1 with USD, register base/USD tokens as base/stablecoin priceAggregator
///		- For ETH use zero address
contract PriceOracle is IPriceOracle, Ownable {
    /// @dev mapping (base => quote => priceAggregator)
    mapping(address => mapping(address => AggregatorV3Interface)) public priceAggregator;

    /// @dev Emitted when a new price aggregator is set
    event SetAggregator(address indexed _by, address indexed _base, address indexed _quote, address _aggregator);

    /// @inheritdoc IPriceOracle
    function setAggregator(address _base, address _quote, address _aggregator) external override onlyOwner {
        priceAggregator[_base][_quote] = AggregatorV3Interface(_aggregator);
        emit SetAggregator(msg.sender, _base, _quote, _aggregator);
    }

    /// @inheritdoc IPriceOracle
    function getPrice(address _base, address _quote) external view override returns (uint256 basePrice) {
        basePrice = uint256(_getAnswer(_base, _quote));
        uint8 priceDecimals = _getPriceDecimals(_base, _quote);
        uint8 quoteDecimals = _getTokenDecimals(_quote);
        if (priceDecimals > quoteDecimals) {
            basePrice /= 10 ** (priceDecimals - quoteDecimals);
        } else if (priceDecimals < quoteDecimals) {
            basePrice *= 10 ** (priceDecimals - quoteDecimals);
        }
    }

    /// @dev Get answer (price) given `_base` and `_quote`
    /// @param _base Base currency address
    /// @param _quote Quote currency address
    /// @return Base price in quote (int256)
    function _getAnswer(address _base, address _quote) internal view returns (int256) {
        (uint256 roundId, int256 priceInBase, , uint256 updatedAt, uint256 answeredInRound) = priceAggregator[_base][
            _quote
        ].latestRoundData();
        require(roundId == answeredInRound, "Invalid Answer");
        require(updatedAt > 0, "Round not complete");
        return priceInBase;
    }

    /// @dev Get price decimals
    /// @param _base Base currency address
    /// @param _quote Quote currency address
    /// @return Number of decimals in price response
    function _getPriceDecimals(address _base, address _quote) internal view returns (uint8) {
        return priceAggregator[_base][_quote].decimals();
    }

    /// @dev Get token decimals
    /// @param _token Token address
    /// @return Number of decimals in `_token`
    function _getTokenDecimals(address _token) internal view returns (uint8) {
        return IERC20Extended(_token).decimals();
    }
}
