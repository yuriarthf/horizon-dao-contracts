// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { FeedRegistryInterface } from "@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol";
import { Denominations } from "@chainlink/contracts/src/v0.8/Denominations.sol";

import { IUniswapV2Router01 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";

interface IERC20Extended is IERC20 {
    function decimals() external view returns (uint8);
}

library IROFinance {
    using SafeERC20 for IERC20;
    uint16 public constant SLIPPAGE_DIVISOR = 10000;
    uint8 public constant ETH_DECIMALS = 18;

    struct Finance {
        IUniswapV2Router01 swapRouter;
        FeedRegistryInterface priceFeedRegistry;
        address weth;
        address basePriceToken;
    }

    function processPayment(
        Finance memory _finance,
        uint256 _unitPrice,
        uint256 _amountToPurchase,
        address _paymentToken,
        uint16 _slippage
    ) internal returns (uint256 valueInBase) {
        valueInBase = _amountToPurchase * _unitPrice;
        if (_paymentToken == _finance.basePriceToken) {
            IERC20(_paymentToken).safeTransferFrom(msg.sender, address(this), valueInBase);
        } else if (_paymentToken != address(0)) {
            uint256 valueInPaymentToken = (convertBaseToPaymentToken(_finance, valueInBase, _paymentToken) *
                SLIPPAGE_DIVISOR +
                _slippage) / SLIPPAGE_DIVISOR;
            IERC20(_paymentToken).safeTransferFrom(msg.sender, address(this), valueInPaymentToken);
            IERC20(_paymentToken).safeApprove(address(_finance.swapRouter), valueInPaymentToken);
            address[] memory path = new address[](2);
            path[0] = _paymentToken;
            path[1] = _finance.basePriceToken;
            uint256[] memory amounts = _finance.swapRouter.swapTokensForExactTokens(
                valueInBase,
                valueInPaymentToken,
                path,
                address(this),
                block.timestamp
            );
            if (amounts[0] < valueInPaymentToken) {
                sendErc20(msg.sender, valueInPaymentToken - amounts[0], _paymentToken);
            }
        } else {
            uint256 valueInEth = (convertBaseToPaymentToken(_finance, valueInBase, _paymentToken) *
                SLIPPAGE_DIVISOR +
                _slippage) / SLIPPAGE_DIVISOR;
            require(msg.value >= valueInEth, "Not enough ethers sent");
            address[] memory path = new address[](2);
            path[0] = _finance.weth;
            path[1] = _finance.basePriceToken;
            uint256[] memory amounts = _finance.swapRouter.swapETHForExactTokens{ value: valueInEth }(
                valueInBase,
                path,
                address(this),
                block.timestamp
            );
            if (msg.value > amounts[0]) {
                sendEther(msg.sender, msg.value - amounts[0]);
            }
        }
    }

    /// @dev Utility function to send an amount of ethers to a given address
    /// @param _to Address to send ethers
    /// @param _amount Amount of ethers to send
    function sendEther(address _to, uint256 _amount) internal {
        (bool success, ) = _to.call{ value: _amount }("");
        require(success, "Failed sending ethers");
    }

    function sendErc20(address _to, uint256 _amount, address _token) internal {
        IERC20(_token).safeTransfer(_to, _amount);
    }

    function convertBaseToPaymentToken(
        Finance memory _finance,
        uint256 _valueInBase,
        address _paymentToken
    ) internal view returns (uint256) {
        uint256 paymentTokenPriceInBase = uint256(getTokenPriceInBaseTokens(_finance, _paymentToken));
        uint8 priceDecimals = _getPriceDecimals(_finance, _paymentToken);
        uint8 baseTokenDecimal = _getTokenDecimals(_finance.basePriceToken);
        uint8 paymentTokenDecimals = _getTokenDecimals(_paymentToken);
        if (priceDecimals > baseTokenDecimal) {
            paymentTokenPriceInBase /= 10 ** (priceDecimals - baseTokenDecimal);
        } else if (priceDecimals < baseTokenDecimal) {
            paymentTokenPriceInBase *= 10 ** (priceDecimals - baseTokenDecimal);
        }
        return (_valueInBase * 10 ** uint256(paymentTokenDecimals)) / paymentTokenPriceInBase;
    }

    function getETHPriceInBaseTokens(Finance memory _finance) internal view returns (int256) {
        (, int256 priceInBase, , uint256 updatedAt, ) = _finance.priceFeedRegistry.latestRoundData(
            Denominations.ETH,
            _finance.basePriceToken
        );
        require(updatedAt > 0, "Round not complete");
        return priceInBase;
    }

    function getTokenPriceInBaseTokens(Finance memory _finance, address _paymentToken) internal view returns (int256) {
        (, int256 priceInBase, , uint256 updatedAt, ) = _finance.priceFeedRegistry.latestRoundData(
            _paymentToken,
            _finance.basePriceToken
        );
        require(updatedAt > 0, "Round not complete");
        return priceInBase;
    }

    function _getTokenDecimals(address _token) private view returns (uint8) {
        if (_token == address(0)) return ETH_DECIMALS;
        return IERC20Extended(_token).decimals();
    }

    function _getPriceDecimals(Finance memory _finance, address _paymentToken) private view returns (uint8) {
        return _finance.priceFeedRegistry.decimals(_paymentToken, _finance.basePriceToken);
    }
}
