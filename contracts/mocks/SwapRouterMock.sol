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

    uint256 public constant PRICE_DECIMALS = 1 ether; // 18 decimals

    uint256 public constant TOKEN_DECIMALS = 1 ether; // 18 decimals

    mapping(address => mapping(address => uint256)) private _price;

    mapping(address => bool) public isTokenRegistered;

    constructor() {}

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
        uint256 price = getPrice(path[0], path[path.length - 1]);
        uint256 payment = (amountOut * TOKEN_DECIMALS) / price;
        require(msg.value >= payment, "!payment");
        IERC20FreeMint(path[path.length - 1]).freeMint(to, amountOut);
        amounts[0] = payment;
        amounts[1] = amountOut;
        if (msg.value > payment) {
            payable(msg.sender).sendValue(msg.value - payment);
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
        uint256 price = getPrice(path[0], path[path.length - 1]);
        uint256 payment = (amountOut * TOKEN_DECIMALS) / price;
        require(payment <= amountInMax, "!amountInMax");
        IERC20(path[0]).safeTransferFrom(msg.sender, address(this), payment);
        IERC20FreeMint(path[path.length - 1]).freeMint(to, amountOut);
        amounts[0] = payment;
        amounts[1] = amountOut;
    }

    function WETH() external view returns (address) {
        return _weth;
    }

    function getPrice(address _base, address _quote) public view returns (uint256) {
        uint256 price = _price[_base][_quote];
        if (price == 0) {
            price = _price[_quote][_base];
            if (price == 0) return DEFAULT_PRICE;
            return (PRICE_DECIMALS * TOKEN_DECIMALS) / price;
        }
        return price;
    }
}
