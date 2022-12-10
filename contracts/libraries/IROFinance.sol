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
    /// @param _paymentToken The address of the token being used for payment
    /// @param _priceWithSlippage Expected price with slippage
    /// @param _amountToPurchase Amount of tokens to purchase
    /// @param _relativePath Swap path relative to the origin and end currency
    /// @param _baseCurrency Address of the token used as the base precification currency
    function processPayment(
        Finance memory _finance,
        uint256 _unitPrice,
        address _paymentToken,
        uint256 _priceWithSlippage,
        uint256 _amountToPurchase,
        address[] memory _relativePath,
        address _baseCurrency
    ) internal returns (uint256 valueInBase) {
        valueInBase = _amountToPurchase * _unitPrice;
        if (_paymentToken == _baseCurrency) {
            require(valueInBase <= _priceWithSlippage, "Invalid amount");
            IERC20Extended(_paymentToken).safeTransferFrom(msg.sender, address(this), valueInBase);
        } else if (_paymentToken != address(0)) {
            IERC20Extended(_paymentToken).safeTransferFrom(msg.sender, address(this), _priceWithSlippage);
            IERC20Extended(_paymentToken).safeApprove(address(_finance.swapRouter), _priceWithSlippage);
            address[] memory path = new address[](_relativePath.length + 2);
            path[0] = _paymentToken;
            for (uint256 i = 0; i < _relativePath.length; i++) {
                path[i + 1] = _relativePath[i];
            }
            path[path.length - 1] = _baseCurrency;
            uint256[] memory amounts = _finance.swapRouter.swapTokensForExactTokens(
                valueInBase,
                _priceWithSlippage,
                path,
                address(this),
                block.timestamp
            );
            if (amounts[0] < _priceWithSlippage) {
                sendErc20(msg.sender, _priceWithSlippage - amounts[0], _paymentToken);
            }
        } else {
            require(msg.value >= _priceWithSlippage, "Not enough ethers sent");
            address[] memory path = new address[](_relativePath.length + 2);
            path[0] = _finance.swapRouter.WETH();
            for (uint256 i = 0; i < _relativePath.length; i++) {
                path[i + 1] = _relativePath[i];
            }
            path[path.length - 1] = _baseCurrency;
            uint256[] memory amounts = _finance.swapRouter.swapETHForExactTokens{ value: _priceWithSlippage }(
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
        amount = (totalPurchased * _share) / (IROFinance.DENOMINATOR - _share);
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
            uint256 listingOwnerAmount,
            uint256 treasuryAmount,
            uint256 realEstateReservesAmount,
            bool realEstateReservesSet
        )
    {
        if (_listingOwnerFee > 0) {
            listingOwnerAmount = (_listingOwnerFee * _totalFunding) / DENOMINATOR;
            sendErc20(_listingOwner, listingOwnerAmount, _baseCurrency);
        }
        treasuryAmount = (_treasuryFee * _totalFunding) / DENOMINATOR;
        realEstateReservesAmount = _totalFunding - (listingOwnerAmount + treasuryAmount);
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
            sendErc20(_treasury, _totalFunding - listingOwnerAmount, _baseCurrency);
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

    /// @dev Get the number of decimals of a token
    /// @param _token Token address
    /// @return Number of decimals
    function _getTokenDecimals(address _token) private view returns (uint8) {
        if (_token == address(0)) return ETH_DECIMALS;
        return IERC20Extended(_token).decimals();
    }
}
