// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { ERC1155Supply } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import { ERC1155URIStorage } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155URIStorage.sol";
import { IERC1155 } from "@openzeppelin/contracts/interfaces/IERC1155.sol";

/// @title Siple Approvable ERC1155
/// @author Yuri Fernandes (HorizonDAO)
/// @dev Allows the approval for a single collection and a certain amount of tokens
///     to be transferred with the allowed party
abstract contract SingleApprovableERC1155 is ERC1155URIStorage, ERC1155Supply {
    /// @dev mapping (collectionId => owner => spender => amount)
    mapping(uint256 => mapping(address => mapping(address => uint256))) private _allowances;

    /// @dev Emitted when allowance is given
    event Approval(uint256 indexed _id, address indexed _owner, address indexed _spender, uint256 _amount);

    /// @notice Approve a spender to transfer tokens
    /// @param _tokenId Collection ID
    /// @param _spender Spender address
    /// @param _amount Amount allowed
    function approve(uint256 _tokenId, address _spender, uint256 _amount) public virtual returns (bool) {
        address owner_ = _msgSender();
        _approve(_tokenId, owner_, _spender, _amount);
        return true;
    }

    /// @inheritdoc IERC1155
    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) public virtual override {
        if (_from != _msgSender() && !isApprovedForAll(_from, _msgSender())) {
            require(_allowances[_id][_from][_msgSender()] >= _amount, "Not authorized");
            _allowances[_id][_from][_msgSender()] -= _amount;
        }
        _safeTransferFrom(_from, _to, _id, _amount, _data);
    }

    /// @inheritdoc IERC1155
    function safeBatchTransferFrom(
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) public virtual override {
        if (_from != _msgSender() && !isApprovedForAll(_from, _msgSender())) {
            for (uint256 i = 0; i < _ids.length; i++) {
                require(_allowances[_ids[i]][_from][_msgSender()] >= _amounts[i], "Not authorized");
                _allowances[_ids[i]][_from][_msgSender()] -= _amounts[i];
            }
        }
        _safeBatchTransferFrom(_from, _to, _ids, _amounts, _data);
    }

    /// @inheritdoc ERC1155URIStorage
    function uri(uint256 _tokenId) public view virtual override(ERC1155, ERC1155URIStorage) returns (string memory) {
        return ERC1155URIStorage.uri(_tokenId);
    }

    /// @dev See {approve} notice
    /// @param _id Collection ID
    /// @param _spender Spender address
    /// @param _amount Amount allowed
    function _approve(uint256 _id, address _owner, address _spender, uint256 _amount) internal virtual {
        require(_owner != address(0), "Approve from the zero address");
        require(_spender != address(0), "Approve to the zero address");

        _allowances[_id][_owner][_spender] = _amount;
        emit Approval(_id, _owner, _spender, _amount);
    }

    /// @inheritdoc ERC1155Supply
    function _beforeTokenTransfer(
        address _operator,
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal virtual override(ERC1155, ERC1155Supply) {
        ERC1155Supply._beforeTokenTransfer(_operator, _from, _to, _ids, _amounts, _data);
    }
}
