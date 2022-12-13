// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { RoyalERC1155Upgradeable } from "../token/RoyalERC1155Upgradeable.sol";

contract RoyalERC1155UpgradeableMock is RoyalERC1155Upgradeable {
    function initialize(string memory _uri, address _admin, address _owner) external initializer {
        __RoyalERC1155_init(_uri, _admin, _owner);
    }

    function initChained(string memory _uri, address _admin, address _owner) external {
        __RoyalERC1155_init(_uri, _admin, _owner);
    }

    function initUnchained(address _owner) external {
        __RoyalERC1155_init_unchained(_owner);
    }
}
