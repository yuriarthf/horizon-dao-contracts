// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IRealEstateReserves } from "../interfaces/IRealEstateReserves.sol";

contract RealEstateFundsMock is IRealEstateReserves {
    using SafeERC20 for IERC20;
    mapping(uint256 => mapping(address => uint256)) public funds;

    function deposit(uint256 _id, uint256 _amount, address _currency) external {
        funds[_id][_currency] += _amount;
        IERC20(_currency).safeTransferFrom(msg.sender, address(this), _amount);
    }
}
