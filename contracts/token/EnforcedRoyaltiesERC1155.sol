// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC1155 } from "@openzeppelin/contracts/interfaces/IERC1155.sol";

import { RoyalERC1155 } from "./RoyalERC1155.sol";
import { SingleApprovableERC1155 } from "./SingleApprovableERC1155.sol";
import { DefaultOperatorFilterer } from "operator-filter-registry/src/DefaultOperatorFilterer.sol";

/// @title Enforced Royalties ERC1155
/// @dev Enable royalties enforcements on marketplaces
///     that enforces offchain royalties
abstract contract EnforcedRoyaltiesERC1155 is RoyalERC1155, DefaultOperatorFilterer {
    /// @dev Initializes RoyalERC1155 contract
    /// @param uri_ Token URI
    /// @param _admin Address of the admin
    /// @param _owner Address with permissions on OpenSea
    constructor(string memory uri_, address _admin, address _owner) RoyalERC1155(uri_, _admin, _owner) {}

    /// @notice Approve a spender to transfer tokens
    /// @param _tokenId Collection ID
    /// @param _spender Spender address
    /// @param _amount Amount allowed
    function approve(
        uint256 _tokenId,
        address _spender,
        uint256 _amount
    ) public virtual override onlyAllowedOperatorApproval(_spender) returns (bool) {
        return super.approve(_tokenId, _spender, _amount);
    }

    /// @inheritdoc IERC1155
    function setApprovalForAll(address operator, bool approved) public override onlyAllowedOperatorApproval(operator) {
        super.setApprovalForAll(operator, approved);
    }

    /// @inheritdoc IERC1155
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        uint256 amount,
        bytes memory data
    ) public override onlyAllowedOperator(from) {
        super.safeTransferFrom(from, to, tokenId, amount, data);
    }

    /// @inheritdoc IERC1155
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public virtual override onlyAllowedOperator(from) {
        super.safeBatchTransferFrom(from, to, ids, amounts, data);
    }
}
