// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IERC20Extended is IERC20 {
    function decimals() external view returns (uint8);
}
