// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20Extended } from "../interfaces/IERC20Extended.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { FeedRegistryInterface } from "@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol";
import { Denominations } from "@chainlink/contracts/src/v0.8/Denominations.sol";

import { IUniswapV2Router01 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";

import { IRealEstateFunds } from "../interfaces/IRealEstateFunds.sol";

/// @title IRO Finance
/// @author Horizon DAO (Yuri Fernandes)
/// @dev Library contain functions to perform financial computations
///     for the InitialRealEstateOffering contract
library IROFinance {
    using SafeERC20 for IERC20Extended;

    /// @dev Number of decimals of ETH
    uint8 public constant ETH_DECIMALS = 18;

    /// @dev The denominator and maximum value for slippage
    uint16 public constant SLIPPAGE_DENOMINATOR = 10000;

    /// @dev The denominator and maximum value for fee
    uint16 public constant FEE_DENOMINATOR = 10000;

    /// @dev The denominator and maximum value for share
    uint16 public constant SHARE_DENOMINATOR = 10000;

    /// @dev Structure that holds all financial types
    ///     used to swap tokens and consult relative prices
    struct Finance {
        IUniswapV2Router01 swapRouter;
        FeedRegistryInterface priceFeedRegistry;
        address weth;
        address basePriceToken;
    }

    /// @dev Initialize the Finance structure
    /// @param _finance Finance structure
    /// @param _swapRouter Address of the Uniswap/Sushiswap router used to swap tokens
    /// @param _priceFeedRegistry Address for Chainlink Price Feed Registry
    /// @param _weth WETH contract address
    /// @param _basePriceToken Address of the token used as the base precification currency
    function initializeFinance(
        Finance storage _finance,
        address _swapRouter,
        address _priceFeedRegistry,
        address _weth,
        address _basePriceToken
    ) internal {
        _finance.swapRouter = IUniswapV2Router01(_swapRouter);
        _finance.priceFeedRegistry = FeedRegistryInterface(_priceFeedRegistry);
        _finance.weth = _weth;
        _finance.basePriceToken = _basePriceToken;
    }

    /// @dev Process commit payment
    /// @param _finance Finance structure
    /// @param _unitPrice Unit price of the token
    /// @param _paymentToken The address of the token being used for payment
    /// @param _amountToPay Expected amount to pay (without slippage)
    /// @param _amountToPurchase Amount of tokens to purchase
    /// @param _slippage Swap slippage in basis points
    function processPayment(
        Finance memory _finance,
        uint256 _unitPrice,
        address _paymentToken,
        uint256 _amountToPay,
        uint256 _amountToPurchase,
        uint16 _slippage
    ) internal returns (uint256 valueInBase) {
        valueInBase = _amountToPurchase * _unitPrice;
        if (_paymentToken == _finance.basePriceToken) {
            require(valueInBase == _amountToPay, "Invalid amount");
            IERC20Extended(_paymentToken).safeTransferFrom(msg.sender, address(this), valueInBase);
        } else if (_paymentToken != address(0)) {
            uint256 valueWithSlippage = (_amountToPay * SLIPPAGE_DENOMINATOR + _slippage) / SLIPPAGE_DENOMINATOR;
            IERC20Extended(_paymentToken).safeTransferFrom(msg.sender, address(this), valueWithSlippage);
            IERC20Extended(_paymentToken).safeApprove(address(_finance.swapRouter), valueWithSlippage);
            address[] memory path = new address[](2);
            path[0] = _paymentToken;
            path[1] = _finance.basePriceToken;
            uint256[] memory amounts = _finance.swapRouter.swapTokensForExactTokens(
                valueInBase,
                valueWithSlippage,
                path,
                address(this),
                block.timestamp
            );
            if (amounts[0] < valueWithSlippage) {
                sendErc20(msg.sender, valueWithSlippage - amounts[0], _paymentToken);
            }
        } else {
            uint256 valueWithSlippage = (_amountToPay * SLIPPAGE_DENOMINATOR + _slippage) / SLIPPAGE_DENOMINATOR;
            require(msg.value >= valueWithSlippage, "Not enough ethers sent");
            address[] memory path = new address[](2);
            path[0] = _finance.weth;
            path[1] = _finance.basePriceToken;
            uint256[] memory amounts = _finance.swapRouter.swapETHForExactTokens{ value: valueWithSlippage }(
                valueInBase,
                path,
                address(this),
                block.timestamp
            );
            if (amounts[0] < msg.value) {
                sendEther(msg.sender, msg.value - amounts[0]);
            }
        }
    }

    /// @notice Get the expected price of an IRO purchase (without slippage)
    /// @param _finance Finance structure
    /// @param _unitPrice Unit price of the token
    /// @param _paymentToken Payment token address
    /// @param _amountToPurchase Amount of IRO tokens to purchase
    function expectedPrice(
        Finance memory _finance,
        uint256 _unitPrice,
        address _paymentToken,
        uint256 _amountToPurchase
    ) internal view returns (uint256) {
        uint256 valueInBase = _amountToPurchase * _unitPrice;
        if (_paymentToken == _finance.basePriceToken) {
            return valueInBase;
        }
        return convertBaseToPaymentToken(_finance, valueInBase, _paymentToken);
    }

    /// @notice Get the expected price of an IRO purchase (without slippage)
    /// @param _finance Finance structure
    /// @param _unitPrice Unit price of the token
    /// @param _paymentToken Payment token address
    /// @param _amountToPurchase Amount of IRO tokens to purchase
    /// @param _slippage Swap slippage in basis points
    function priceWithSlippage(
        Finance memory _finance,
        uint256 _unitPrice,
        address _paymentToken,
        uint256 _amountToPurchase,
        uint16 _slippage
    ) internal view returns (uint256) {
        uint256 expectedPrice_ = expectedPrice(_finance, _unitPrice, _paymentToken, _amountToPurchase);
        if (_paymentToken == _finance.basePriceToken) return expectedPrice_;
        return (expectedPrice_ * (SLIPPAGE_DENOMINATOR + _slippage)) / SLIPPAGE_DENOMINATOR;
    }

    /// @dev Convert token share to amount
    /// @param _totalFunding Total IRO funding
    /// @param _unitPrice IRO token unit price
    /// @param _share Token share
    /// @return amount Amount of tokens
    function shareToAmount(
        uint256 _totalFunding,
        uint256 _unitPrice,
        uint16 _share
    ) internal pure returns (uint256 amount) {
        uint256 totalPurchased = _totalFunding / _unitPrice;
        amount = (totalPurchased * _share) / (IROFinance.SHARE_DENOMINATOR - _share);
    }

    /// @dev Distribute funds during IRO withdrawal
    /// @param _finance Finance structure
    /// @param _listingOwner The listing owner of the IRO
    /// @param _treasury Treasury contract address
    /// @param _realEstateFunds RealEstateFunds contract address
    /// @param _realEstateId ID of the RealEstate token to receive the funds
    /// @param _totalFunding Total funds from the IRO
    /// @param _listingOwnerFee Fee requested by the listing owner
    /// @param _treasuryFee Treasury fee
    function distributeFunds(
        Finance memory _finance,
        address _listingOwner,
        address _treasury,
        IRealEstateFunds _realEstateFunds,
        uint256 _realEstateId,
        uint256 _totalFunding,
        uint256 _listingOwnerFee,
        uint256 _treasuryFee
    ) internal returns (uint256 listingOwnerAmount, uint256 treasuryAmount, uint256 realEstateFundsAmount) {
        if (_listingOwnerFee > 0) {
            listingOwnerAmount = (_listingOwnerFee * _totalFunding) / FEE_DENOMINATOR;
            sendErc20(_listingOwner, listingOwnerAmount, _finance.basePriceToken);
        }
        if (_treasuryFee > 0) {
            treasuryAmount = (_treasuryFee * _totalFunding) / FEE_DENOMINATOR;
            sendErc20(_treasury, treasuryAmount, _finance.basePriceToken);
        }
        realEstateFundsAmount = _totalFunding - (listingOwnerAmount + treasuryAmount);
        if (realEstateFundsAmount > 0) {
            IERC20Extended(_finance.basePriceToken).safeApprove(address(_realEstateFunds), realEstateFundsAmount);
            _realEstateFunds.deposit(_realEstateId, realEstateFundsAmount, _finance.basePriceToken);
        }
    }

    /// @dev Utility function to send an amount of ethers to a given address
    /// @param _to Address to send ethers
    /// @param _amount Amount of ethers to send
    function sendEther(address _to, uint256 _amount) internal {
        (bool success, ) = _to.call{ value: _amount }("");
        require(success, "Failed sending ethers");
    }

    /// @dev Utility function to send an amount of ERC20 tokens to a given address
    /// @param _to Address to send tokens
    /// @param _amount Amount of tokens to send
    /// @param _token Address of the token to send
    function sendErc20(address _to, uint256 _amount, address _token) internal {
        IERC20Extended(_token).safeTransfer(_to, _amount);
    }

    /// @dev Convert a base currency amount to a given payment token
    /// @param _finance Finance structure
    /// @param _valueInBase Value in base tokens
    /// @param _paymentToken Payment token address
    /// @return Price in payment tokens
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

    /// @dev Get ETH price in base tokens
    /// @param _finance Finance structure
    /// @return Price in base tokens
    function getETHPriceInBaseTokens(Finance memory _finance) internal view returns (int256) {
        (uint256 roundId, int256 priceInBase, , uint256 updatedAt, uint256 answeredInRound) = _finance
            .priceFeedRegistry
            .latestRoundData(Denominations.ETH, _finance.basePriceToken);
        require(roundId == answeredInRound, "Invalid Answer");
        require(updatedAt > 0, "Round not complete");
        return priceInBase;
    }

    /// @dev Get token price in base tokens
    /// @param _finance Finance structure
    /// @return Price in base tokens
    function getTokenPriceInBaseTokens(Finance memory _finance, address _paymentToken) internal view returns (int256) {
        (uint256 roundId, int256 priceInBase, , uint256 updatedAt, uint256 answeredInRound) = _finance
            .priceFeedRegistry
            .latestRoundData(_paymentToken, _finance.basePriceToken);
        require(roundId == answeredInRound, "Invalid Answer");
        require(updatedAt > 0, "Round not complete");
        return priceInBase;
    }

    /// @dev Get the number of decimals of a token
    /// @param _token Token address
    /// @return Number of decimals
    function _getTokenDecimals(address _token) private view returns (uint8) {
        if (_token == address(0)) return ETH_DECIMALS;
        return IERC20Extended(_token).decimals();
    }

    /// @dev Get the number of decimals in the price of `_paymentToken` in base
    /// @param _finance Finance structure
    /// @param _paymentToken Payment token address
    /// @return Price decimals
    function _getPriceDecimals(Finance memory _finance, address _paymentToken) private view returns (uint8) {
        return _finance.priceFeedRegistry.decimals(_paymentToken, _finance.basePriceToken);
    }
}
