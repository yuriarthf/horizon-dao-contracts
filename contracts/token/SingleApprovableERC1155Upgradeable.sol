// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {
    ERC1155SupplyUpgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";

abstract contract SingleApprovableERC1155Upgradeable is ERC1155SupplyUpgradeable {
    mapping(uint256 => mapping(address => mapping(address => uint256))) private _allowances;

    event Approval(uint256 indexed _id, address indexed _owner, address indexed _spender, uint256 _amount);

    function __SingleApprovableERC1155_init(string memory _uri) internal onlyInitializing {
        __ERC1155_init_unchained(_uri);
        __ERC1155Supply_init_unchained();
        __SingleApprovableERC1155_init_unchained();
    }

    function __SingleApprovableERC1155_init_unchained() internal onlyInitializing {}

    function approve(
        uint256 _id,
        address _spender,
        uint256 _amount
    ) public returns (bool) {
        address owner_ = _msgSender();
        _approve(_id, owner_, _spender, _amount);
        return true;
    }

    function safeTransferFrom(
        address _from,
        address _to,
        uint256 _id,
        uint256 _amount,
        bytes memory _data
    ) public override {
        if (_from != _msgSender() && !isApprovedForAll(_from, _msgSender())) {
            require(_allowances[_id][_from][_msgSender()] >= _amount, "Not authorized");
            _allowances[_id][_from][_msgSender()] -= _amount;
        }
        _safeTransferFrom(_from, _to, _id, _amount, _data);
    }

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

    function _approve(
        uint256 _id,
        address _owner,
        address _spender,
        uint256 _amount
    ) internal virtual {
        require(_owner != address(0), "Approve from the zero address");
        require(_spender != address(0), "Approve to the zero address");

        _allowances[_id][_owner][_spender] = _amount;
        emit Approval(_id, _owner, _spender, _amount);
    }
}
