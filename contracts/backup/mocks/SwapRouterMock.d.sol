// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IERC20FreeMint is IERC20 {
    function freeMint(address _to, uint256 _amount) external;
}

contract SwapRouterMock {
    using Address for address payable;
    using SafeERC20 for IERC20;

    address private _weth;

    uint256 public constant DEFAULT_PRICE = 1 ether;

    uint16 public constant FEE_DENOMINATOR = 10000;

    uint8 public constant ETH_DECIMALS = 18;

    uint8 public immutable priceDecimals;

    uint8 public immutable tokenDecimals;

    uint16 public immutable fee;

    mapping(address => mapping(address => uint256)) private _price;

    mapping(address => bool) public isTokenRegistered;

    constructor() {
        priceDecimals = 18;
        tokenDecimals = 18;
        fee = 30;
    }

    function setWethMock(address weth_) external {
        _weth = weth_;
    }

    function registerToken(address _token) external {
        isTokenRegistered[_token] = true;
    }

    function setPrice(address _base, address _quote, uint256 price_) external {
        _price[_base][_quote] = price_;
        isTokenRegistered[_quote] = true;
        isTokenRegistered[_base] = true;
    }

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint
    ) external payable returns (uint[] memory amounts) {
        require(path[0] == _weth, "!ETH");
        require(path.length > 1, "path.length > 1");
        require(isTokenRegistered[path[path.length - 1]], "Swap not allowed");
        uint256 price = getNormalizedPrice(path[0], path[path.length - 1]);
        uint256 payment = (amountOut * 10 ** ETH_DECIMALS) / price;
        uint256 priceWithFee = (payment * (FEE_DENOMINATOR + fee * (path.length - 1))) / FEE_DENOMINATOR;
        require(msg.value >= priceWithFee, "!payment");
        IERC20FreeMint(path[path.length - 1]).freeMint(to, amountOut);
        amounts[0] = priceWithFee;
        amounts[1] = amountOut;
        if (msg.value > priceWithFee) {
            payable(msg.sender).sendValue(msg.value - priceWithFee);
        }
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint
    ) external returns (uint[] memory amounts) {
        require(path[0] != address(0), "Invalid Token");
        require(path.length > 1, "path.length > 1");
        require(isTokenRegistered[path[path.length - 1]], "Swap not allowed");
        uint256 price = getNormalizedPrice(path[0], path[path.length - 1]);
        uint256 payment = (amountOut * 10 ** tokenDecimals) / price;
        uint256 priceWithFee = (payment * (FEE_DENOMINATOR + fee * (path.length - 1))) / FEE_DENOMINATOR;
        require(payment <= amountInMax, "!amountInMax");
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), priceWithFee);
        IERC20FreeMint(path[path.length - 1]).freeMint(to, amountOut);
        amounts[0] = priceWithFee;
        amounts[1] = amountOut;
    }

    function WETH() external view returns (address) {
        return _weth;
    }

    function getNormalizedPrice(address _base, address _quote) public view returns (uint256) {
        uint256 price = _price[_base][_quote];
        uint8 baseDecimals = _base == address(0) ? ETH_DECIMALS : tokenDecimals;
        if (price == 0) {
            price = _price[_quote][_base];
            if (price == 0) return _normalizePrice(DEFAULT_PRICE, baseDecimals);
            return (10 ** baseDecimals) ** 2 / _normalizePrice(price, baseDecimals);
        }
        return _normalizePrice(price, baseDecimals);
    }

    function _normalizePrice(uint256 price_, uint8 _tokenDecimals) internal view returns (uint256) {
        if (_tokenDecimals > priceDecimals) {
            return price_ * (10 ** (_tokenDecimals - priceDecimals));
        } else if (priceDecimals > _tokenDecimals) {
            return price_ / (10 ** (priceDecimals - _tokenDecimals));
        }
        return price_;
    }
}
