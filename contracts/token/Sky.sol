// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title SkyERC20
/// @notice HorizonDAO Governance token
/// @author Yuri Fernandes
contract SkyERC20 is ERC20 {
    /// @dev Maximum supply of 100M tokens (with 18 decimal points)
    uint256 public constant MAX_SUPPLY = 100_000_000 * 10**18;

    // solhint-disable-next-line
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {}
}
