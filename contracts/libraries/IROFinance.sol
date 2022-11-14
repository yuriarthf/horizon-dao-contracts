// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { FeedRegistryInterface } from "@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol";
import { Denominations } from "@chainlink/contracts/src/v0.8/Denominations.sol";

import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface IERC20Extended is IERC20 {
    function decimals() external view returns (uint8);
}

library IROFinance {
    using SafeERC20 for IERC20;
    uint64 public constant ETH_DECIMALS = 1e18;

    struct Finance {
        IUniswapV2Router02 swapRouter;
        FeedRegistryInterface priceFeedRegistry;
        address weth;
        address basePriceToken;
    }

    function processPaymentForToken(
        Finance memory _finance,
        uint256 _value,
        address _paymentToken,
        uint256 _unitPrice
    ) internal returns (uint128 purchasedAmount, uint256 valueInBase) {
        uint256 requiredValue;
        if (_paymentToken == _finance.basePriceToken) {
            purchasedAmount = uint128(_value / _unitPrice);
            require(purchasedAmount > 0, "Insufficient payment");
            valueInBase = purchasedAmount * _unitPrice;
            IERC20(_paymentToken).safeTransferFrom(msg.sender, address(this), valueInBase);
        } else if (_paymentToken != address(0)) {
            uint256 priceInBase = uint256(getTokenPriceInBaseTokens(_finance, _paymentToken));
            uint256 paymentTokenDecimals = 10 ** uint256(IERC20Extended(_paymentToken).decimals());
            purchasedAmount = uint128(((_value * priceInBase) / _unitPrice) / paymentTokenDecimals);
            require(purchasedAmount > 0, "Insufficient payment");
            valueInBase = purchasedAmount * _unitPrice;
            requiredValue = uint256((valueInBase * paymentTokenDecimals) / priceInBase);
            IERC20(_paymentToken).safeTransferFrom(msg.sender, address(this), requiredValue);
            IERC20(_paymentToken).safeApprove(address(_finance.swapRouter), requiredValue);
            address[] memory path = new address[](2);
            path[0] = _paymentToken;
            path[1] = _finance.basePriceToken;
            _finance.swapRouter.swapExactTokensForTokens(
                requiredValue,
                valueInBase,
                path,
                address(this),
                block.timestamp
            );
        } else {
            (, int256 priceInBase, , , ) = _finance.priceFeedRegistry.latestRoundData(
                Denominations.ETH,
                _finance.basePriceToken
            );
            uint256 baseQuote = uint256(_scalePrice(_finance, priceInBase, _finance.basePriceToken));
            purchasedAmount = uint128(((_value * baseQuote) / _unitPrice) / ETH_DECIMALS);
            require(purchasedAmount > 0, "Insufficient payment");
            valueInBase = purchasedAmount * _unitPrice;
            requiredValue = (valueInBase * ETH_DECIMALS) / baseQuote;
            address[] memory path = new address[](2);
            path[0] = _finance.weth;
            path[1] = _finance.basePriceToken;
            _finance.swapRouter.swapExactETHForTokens{ value: requiredValue }(
                valueInBase,
                path,
                address(this),
                block.timestamp
            );
            _sendValue(msg.sender, msg.value - requiredValue);
        }
    }

    function getETHPriceInBaseTokens(Finance memory _finance) internal view returns (int256) {
        (, int256 priceInBase, , uint256 updatedAt, ) = _finance.priceFeedRegistry.latestRoundData(
            Denominations.ETH,
            _finance.basePriceToken
        );
        require(updatedAt > 0, "Round not complete");
        return _scalePrice(_finance, priceInBase, address(0));
    }

    function getTokenPriceInBaseTokens(Finance memory _finance, address _paymentToken) internal view returns (int256) {
        (, int256 priceInBase, , uint256 updatedAt, ) = _finance.priceFeedRegistry.latestRoundData(
            _paymentToken,
            _finance.basePriceToken
        );
        require(updatedAt > 0, "Round not complete");
        return _scalePrice(_finance, priceInBase, _paymentToken);
    }

    function _scalePrice(Finance memory _finance, int256 _price, address _token) private view returns (int256) {
        uint8 priceDecimals = _finance.priceFeedRegistry.decimals(
            _token != address(0) ? _token : Denominations.ETH,
            _finance.basePriceToken
        );
        uint8 tokenDecimals = IERC20Extended(_token).decimals();
        if (priceDecimals < tokenDecimals) {
            return _price * int256(10 ** uint256(tokenDecimals - priceDecimals));
        } else if (priceDecimals > tokenDecimals) {
            return _price * int256(10 ** uint256(priceDecimals - tokenDecimals));
        }
        return _price;
    }

    /// @dev Utility function to send an amount of ethers to a given address
    /// @param _to Address to send ethers
    /// @param _amount Amount of ethers to send
    function _sendValue(address _to, uint256 _amount) private {
        (bool success, ) = _to.call{ value: _amount }("");
        require(success, "Failed sending ethers");
    }
}
