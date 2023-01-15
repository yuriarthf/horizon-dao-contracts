// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { ERC1155SupplyUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155SupplyUpgradeable.sol";
import { ERC1155URIStorageUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/ERC1155URIStorageUpgradeable.sol";
import { IERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/interfaces/IERC1155Upgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

/// @title Upgradeable Siple Approvable ERC1155
/// @author Yuri Fernandes (HorizonDAO)
/// @dev Allows the approval for a single collection and a certain amount of tokens
///     to be transferred with the allowed party
abstract contract SingleApprovableERC1155Upgradeable is UUPSUpgradeable, ERC1155SupplyUpgradeable {
    function __SingleApprovableERC1155_init(string memory _uri, address _admin) internal onlyInitializing {
        __UUPSUpgradeable_init();
        __ERC1155_init(_uri);
        __ERC1155Supply_init();
        __SingleApprovableERC1155_init_unchained(_admin);
    }

    function __SingleApprovableERC1155_init_unchained(address _admin) internal onlyInitializing {
        // set contract admin
        admin = _admin;
        emit NewAdmin(_admin);
    }

    // Optional base URI
    string public baseURI;

    /// @dev Address of the admin: Can set a new admin among other privileged roles
    address public admin;

    /// @dev mapping (collectionId => owner => spender => amount)
    mapping(uint256 => mapping(address => mapping(address => uint256))) private _allowances;

    /// @dev Emitted when allowance is given
    event Approval(uint256 indexed _id, address indexed _owner, address indexed _spender, uint256 _amount);

    /// @dev Emitted when a new admin is set
    event NewAdmin(address indexed _admin);

    /// @dev Checks if msg.sender is the admin
    modifier onlyAdmin() {
        require(msg.sender == admin, "!admin");
        _;
    }

    /// @dev Set new admin role
    /// @param _admin New admin address
    function setAdmin(address _admin) external onlyAdmin {
        require(admin != _admin, "admin == _admin");
        admin = _admin;
        emit NewAdmin(_admin);
    }

    /// @dev Sets the {baseURI} for the contract tokens
    /// @param baseURI_ Base URI string ended by SLASH
    function setBaseURI(string memory baseURI_) external onlyAdmin {
        _setBaseURI(baseURI_);
    }

    /// @notice Get implementation address
    function implementation() external view returns (address) {
        return _getImplementation();
    }

    /// @notice Approve a spender to transfer tokens
    /// @param _tokenId Collection ID
    /// @param _spender Spender address
    /// @param _amount Amount allowed
    function approve(uint256 _tokenId, address _spender, uint256 _amount) public returns (bool) {
        address owner_ = _msgSender();
        _approve(_tokenId, owner_, _spender, _amount);
        return true;
    }

    /// @inheritdoc IERC1155Upgradeable
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

    /// @inheritdoc IERC1155Upgradeable
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

    /// @notice Returns the {baseURI} concatenated with {tokenId}
    /// @param _tokenId to get the matadata URI
    function uri(uint256 _tokenId) public view virtual override returns (string memory) {
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, _tokenId)) : super.uri(_tokenId);
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

    /// @inheritdoc ERC1155SupplyUpgradeable
    function _beforeTokenTransfer(
        address _operator,
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal virtual override {
        ERC1155SupplyUpgradeable._beforeTokenTransfer(_operator, _from, _to, _ids, _amounts, _data);
    }

    /// @dev Sets `baseURI` as the `_baseURI` for all tokens
    /// @param baseURI_ Base URI string ended by SLASH
    function _setBaseURI(string memory baseURI_) internal virtual {
        baseURI = baseURI_;
    }

    /// @dev Restrict upgrading to the admin role
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyAdmin {}

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}
