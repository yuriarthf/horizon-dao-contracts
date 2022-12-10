// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20Extended } from "../interfaces/IERC20Extended.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { FeedRegistryInterface } from "@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol";
import { Denominations } from "@chainlink/contracts/src/v0.8/Denominations.sol";

import { IUniswapV2Router01 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";

import { IRealEstateReserves } from "../interfaces/IRealEstateReserves.sol";
import { IPriceOracle } from "../interfaces/IPriceOracle.sol";

/// @title IRO Finance
/// @author Horizon DAO (Yuri Fernandes)
/// @dev Library contain functions to perform financial computations
///     for the InitialRealEstateOffering contract
library IROFinance {
    using SafeERC20Upgradeable for IERC20Extended;

    /// @dev Number of decimals of ETH
    uint8 public constant ETH_DECIMALS = 18;

    /// @dev Denominator used for basis point division
    uint16 public constant DENOMINATOR = 10000;

    /// @dev The swap fee in basis points (0.3%)
    uint16 public constant SWAP_FEE = 30;

    /// @dev Structure that holds all financial types
    ///     used to swap tokens and consult relative prices
    struct Finance {
        IUniswapV2Router01 swapRouter;
        IPriceOracle priceOracle;
        address baseCurrency;
    }

    /// @dev Initialize the Finance structure
    /// @param _finance Finance structure
    /// @param _swapRouter Address of the Uniswap/Sushiswap router used to swap tokens
    /// @param _priceOracle Price Oracle address
    /// @param _baseCurrency Address of the token used as the base precification currency
    function initializeFinance(
        Finance storage _finance,
        address _swapRouter,
        address _priceOracle,
        address _baseCurrency
    ) internal {
        _finance.swapRouter = IUniswapV2Router01(_swapRouter);
        _finance.priceOracle = IPriceOracle(_priceOracle);
        _finance.baseCurrency = _baseCurrency;
    }

    /// @dev Process commit payment
    /// @param _finance Finance structure
    /// @param _unitPrice Unit price of the token
    /// @param _paymentCurrency Payment currency address
    /// @param _priceWithSlippage Expected price with slippage
    /// @param _amountToPurchase Amount of tokens to purchase
    /// @param _relativePath Swap path relative to the origin and end currency
    /// @param _baseCurrency Address of the token used as the base precification currency
    function processPayment(
        Finance memory _finance,
        uint256 _unitPrice,
        address _paymentCurrency,
        uint256 _priceWithSlippage,
        uint256 _amountToPurchase,
        address[] memory _relativePath,
        address _baseCurrency
    ) internal returns (uint256 valueInBase) {
        valueInBase = _amountToPurchase * _unitPrice;
        if (_paymentCurrency == _baseCurrency) {
            require(valueInBase <= _priceWithSlippage, "Invalid amount");
            IERC20Extended(_paymentCurrency).safeTransferFrom(msg.sender, address(this), valueInBase);
        } else if (_paymentCurrency != address(0)) {
            _processSecundaryCurrencyPayment(
                _finance.swapRouter,
                _paymentCurrency,
                _baseCurrency,
                _relativePath,
                _priceWithSlippage,
                valueInBase
            );
        } else {
            require(msg.value >= _priceWithSlippage, "Not enough ethers sent");
            _processEthPayment(_finance.swapRouter, _baseCurrency, _relativePath, _priceWithSlippage, valueInBase);
        }
    }

    /// @notice Get the expected price of an IRO purchase (without slippage)
    /// @param _finance Finance structure
    /// @param _unitPrice Unit price of the token
    /// @param _currency Payment token address
    /// @param _amountToPurchase Amount of IRO tokens to purchase
    /// @param _pathLength Swap path length
    /// @param _baseCurrency Address of the token used as the base precification currency
    function expectedPrice(
        Finance memory _finance,
        uint256 _unitPrice,
        address _currency,
        uint256 _amountToPurchase,
        uint256 _pathLength,
        address _baseCurrency
    ) internal view returns (uint256) {
        uint256 valueInBase = _amountToPurchase * _unitPrice;
        if (_currency == _baseCurrency) {
            return valueInBase;
        }
        return
            (convertBaseToPaymentToken(_finance, valueInBase, _currency, _baseCurrency) *
                (DENOMINATOR + (_pathLength - 1) * SWAP_FEE)) / DENOMINATOR;
    }

    /// @notice Get the price with slippage
    /// @param _finance Finance structure
    /// @param _unitPrice Unit price of the token
    /// @param _paymentToken Payment token address
    /// @param _amountToPurchase Amount of IRO tokens to purchase
    /// @param _slippage Swap slippage in basis points
    /// @param _pathLength Swap path length
    /// @param _baseCurrency Address of the token used as the base precification currency
    function priceWithSlippage(
        Finance memory _finance,
        uint256 _unitPrice,
        address _paymentToken,
        uint256 _amountToPurchase,
        uint16 _slippage,
        uint256 _pathLength,
        address _baseCurrency
    ) internal view returns (uint256) {
        uint256 expectedPrice_ = expectedPrice(
            _finance,
            _unitPrice,
            _paymentToken,
            _amountToPurchase,
            _pathLength,
            _baseCurrency
        );
        if (_paymentToken == _baseCurrency) return expectedPrice_;
        return (expectedPrice_ * (DENOMINATOR + _slippage)) / DENOMINATOR;
    }

    /// @dev Calculate listing owner amount
    /// @dev Should be less than 100% or it will overflows
    /// @param _totalFunding Total IRO funding
    /// @param _unitPrice IRO token unit price
    /// @param _share Listing owner token share
    /// @return amount Amount of tokens
    function listingOwnerAmount(
        uint256 _totalFunding,
        uint256 _unitPrice,
        uint16 _share
    ) internal pure returns (uint256 amount) {
        uint256 totalPurchased = _totalFunding / _unitPrice;
        amount = (totalPurchased * _share) / (DENOMINATOR - _share);
    }

    /// @dev Expected token total supply taking into consideration
    ///     the listing owner share and current funding
    /// @param _totalFunding Total IRO funding
    /// @param _unitPrice IRO token unit price
    /// @param _listingOwnerShare Listing owner token share
    /// @return amount Amount of tokens
    function expectedTotalSupply(
        uint256 _totalFunding,
        uint256 _unitPrice,
        uint16 _listingOwnerShare
    ) internal pure returns (uint256) {
        return _totalFunding / _unitPrice + listingOwnerAmount(_totalFunding, _unitPrice, _listingOwnerShare);
    }

    /// @dev Distribute funds during IRO withdrawal
    /// @param _listingOwner The listing owner of the IRO
    /// @param _treasury Treasury contract address
    /// @param _realEstateReserves RealEstateReserves contract address
    /// @param _realEstateId ID of the RealEstate token to receive the funds
    /// @param _totalFunding Total funds from the IRO
    /// @param _listingOwnerFee Fee requested by the listing owner
    /// @param _treasuryFee Treasury fee
    /// @param _baseCurrency Address of the token used as the base precification currency
    function distributeFunds(
        address _listingOwner,
        address _treasury,
        IRealEstateReserves _realEstateReserves,
        uint256 _realEstateId,
        uint256 _totalFunding,
        uint256 _listingOwnerFee,
        uint256 _treasuryFee,
        address _baseCurrency
    )
        internal
        returns (
            uint256 listingOwnerAmount_,
            uint256 treasuryAmount,
            uint256 realEstateReservesAmount,
            bool realEstateReservesSet
        )
    {
        if (_listingOwnerFee > 0) {
            listingOwnerAmount_ = (_listingOwnerFee * _totalFunding) / DENOMINATOR;
            sendErc20(_listingOwner, listingOwnerAmount_, _baseCurrency);
        }
        treasuryAmount = (_treasuryFee * _totalFunding) / DENOMINATOR;
        realEstateReservesAmount = _totalFunding - (listingOwnerAmount_ + treasuryAmount);
        if (address(_realEstateReserves) != address(0)) {
            realEstateReservesSet = true;
            if (treasuryAmount > 0) {
                sendErc20(_treasury, treasuryAmount, _baseCurrency);
            }

            if (realEstateReservesAmount > 0) {
                IERC20Extended(_baseCurrency).safeApprove(address(_realEstateReserves), realEstateReservesAmount);
                _realEstateReserves.deposit(_realEstateId, realEstateReservesAmount, _baseCurrency);
            }
        } else {
            sendErc20(_treasury, _totalFunding - listingOwnerAmount_, _baseCurrency);
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
        address _paymentToken,
        address _baseCurrency
    ) internal view returns (uint256) {
        uint256 paymentTokenPriceInBase = _finance.priceOracle.getPrice(_paymentToken, _baseCurrency);

        return (_valueInBase * 10 ** uint256(_getTokenDecimals(_paymentToken))) / paymentTokenPriceInBase;
    }

    /// @dev process ETH payment
    /// @param _swapRouter IUniswapV2Router01 swap router
    /// @param _baseCurrency The IRO base payment currency
    /// @param _route Route between ETH and the base payment currency
    /// @param _payment Value to pay
    /// @param _valueInBaseCurrency Value in base payment currency
    function _processEthPayment(
        IUniswapV2Router01 _swapRouter,
        address _baseCurrency,
        address[] memory _route,
        uint256 _payment,
        uint256 _valueInBaseCurrency
    ) private {
        address[] memory path = _assemblePath(_swapRouter.WETH(), _route, _baseCurrency);
        uint256[] memory amounts = _swapRouter.swapETHForExactTokens{ value: _payment }(
            _valueInBaseCurrency,
            path,
            address(this),
            block.timestamp
        );
        if (amounts[0] < msg.value) {
            sendEther(msg.sender, msg.value - amounts[0]);
        }
    }

    /// @dev Process secundary currency payment
    /// @param _swapRouter IUniswapV2Router01 swap router
    /// @param _paymentCurrency Secundary payment currency address
    /// @param _baseCurrency The IRO base payment currency
    /// @param _route Route between ETH and the base payment currency
    /// @param _payment Value to pay
    /// @param _valueInBaseCurrency Value in base payment currency
    function _processSecundaryCurrencyPayment(
        IUniswapV2Router01 _swapRouter,
        address _paymentCurrency,
        address _baseCurrency,
        address[] memory _route,
        uint256 _payment,
        uint256 _valueInBaseCurrency
    ) private {
        IERC20Extended(_paymentCurrency).safeTransferFrom(msg.sender, address(this), _payment);
        IERC20Extended(_paymentCurrency).safeApprove(address(_swapRouter), _payment);
        address[] memory path = _assemblePath(_paymentCurrency, _route, _baseCurrency);
        uint256[] memory amounts = _swapRouter.swapTokensForExactTokens(
            _valueInBaseCurrency,
            _payment,
            path,
            address(this),
            block.timestamp
        );
        if (amounts[0] < _payment) {
            sendErc20(msg.sender, _payment - amounts[0], _paymentCurrency);
        }
    }

    /// @dev Get the number of decimals of a token
    /// @param _token Token address
    /// @return Number of decimals
    function _getTokenDecimals(address _token) private view returns (uint8) {
        if (_token == address(0)) return ETH_DECIMALS;
        return IERC20Extended(_token).decimals();
    }

    /// @dev Assemble swap router path
    /// @param _entry Entry currency address
    /// @param _route Route between entry and exit
    /// @param _exit End currency address
    function _assemblePath(
        address _entry,
        address[] memory _route,
        address _exit
    ) private pure returns (address[] memory path) {
        path[0] = _entry;
        for (uint256 i = 0; i < _route.length; i++) {
            path[i + 1] = _route[i];
        }
        path[path.length - 1] = _exit;
    }
}
