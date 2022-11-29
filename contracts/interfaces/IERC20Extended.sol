// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC20Upgradeable.sol";

interface IERC20Extended is IERC20Upgradeable {
    function decimals() external view returns (uint8);
}
