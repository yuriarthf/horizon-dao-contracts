// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { CountersUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import { RoyalERC1155UpgradeableMock } from "./RoyalERC1155UpgradeableMock.sol";

contract RealEstateERC1155Mock is RoyalERC1155UpgradeableMock {
    using CountersUpgradeable for CountersUpgradeable.Counter;

    CountersUpgradeable.Counter private _currentId;

    function mint(uint256 _id, address _to, uint256 _amount) external {
        if (totalSupply(_id) == 0) {
            require(_id == 0 || totalSupply(_id - 1) > 0, "IDs should be sequential");
            _currentId.increment();
        }
        _mint(_to, _id, _amount, bytes(""));
    }

    /// @notice Returns the ID of the next available reNFT
    function nextRealEstateId() external view returns (uint256) {
        return _currentId.current();
    }
}
