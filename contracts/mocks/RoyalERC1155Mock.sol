// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { RoyalERC1155 } from "../token/RoyalERC1155.sol";

contract RoyalERC1155Mock is RoyalERC1155 {
    constructor(string memory _uri, address _admin, address _owner) RoyalERC1155(_uri, _admin, _owner) {}
}
