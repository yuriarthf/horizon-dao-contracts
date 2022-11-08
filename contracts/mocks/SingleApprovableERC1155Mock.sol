// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { SingleApprovableERC1155 } from "../token/SingleApprovableERC1155.sol";

contract SingleApprovableERC1155Mock is SingleApprovableERC1155 {
    constructor(string memory _uri) ERC1155(_uri) {}
}
