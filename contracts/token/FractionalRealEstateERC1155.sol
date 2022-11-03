// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { IERC1155MetadataURI } from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import { BitMaps } from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { RoyalERC1155 } from "./RoyalERC1155.sol";

/// @title Fractional Real Estate NFT
/// @author Yuri Fernandes (HorizonDAO)
/// @notice Used to Tokenize and Fractionate Real Estate
/// @notice Users are required to renovate (check-in) after a certain amount of time
///     or their assets can be liquidated (necessary since reNFT holders can claim deeds if a buyout occur)
/// @notice Only a predefined minter can mint tokens and on a incremental order
contract FractionalRealEstateERC1155 is RoyalERC1155 {
    using BitMaps for BitMaps.BitMap;
    using Counters for Counters.Counter;
    using Strings for uint256;
    using Address for address;

    /// @dev Address of the minter: Can execute mint function
    address public minter;

    /// @dev Address of the burner: Can execute burning functions
    address public burner;

    /// @dev Address responsible to move expired accounts tokens
    address public liquidator;

    /// @dev mapping (collectionId => collectionName)
    mapping(uint256 => string) public collectionName;

    /// @dev mapping (collectionId => collectionSymbol)
    mapping(uint256 => string) public collectionSymbol;

    /// @dev mapping (collectionId => renovationTime)
    /// @dev When users renovate it's signature on reNFTs ownership
    /// users' expiration time will be extended to current_time + collectionRenovationTime
    mapping(uint256 => uint256) public collectionRenovationTime;

    /// @dev mapping (tokenId => account => expiration time)
    /// @dev Users' reNFTs can be put to auction after current_time >= accountExpirationTime,
    /// in order to avoid it, users should renovate it's expiration time
    mapping(uint256 => mapping(address => uint256)) public accountExpirationTime;

    /// @dev mapping (tokenId => isInitialized)
    /// @dev when a tokenId is initialized, it means it cannot change afterwards
    BitMaps.BitMap private _metadataInitialized;

    /// @dev mapping (contract => isPerpetual)
    /// @dev Some addresses might need perpetual ownership in order
    ///     to use reNFTs as collateral, among other additional utilities,
    ///     to do so, they need to be safe of liquidation
    mapping(address => bool) public isPerpetual;

    /// @dev Current value shows the next available collection ID
    Counters.Counter private _currentId;

    /// @dev Emitted when the renovation time of an user is updated (by itself)
    event RenovationTimeUpdated(uint256 indexed _id, address indexed _account, uint256 _updatedAt, uint256 _extendedTo);

    /// @dev Emitted when a new reNFT collection metadata is configured
    event SetCollectionMetadata(uint256 indexed _id, string _name, string _symbol, uint256 _renovationTime);

    /// @dev Emitted when a new minter is set
    event NewMinter(address indexed _minter);

    /// @dev Emitted when a new burner is set
    event NewBurner(address indexed _burner);

    /// @dev Emitted when new reNFTs are minted
    event RealEstateNFTMinted(uint256 indexed _id, address indexed _minter, address indexed _to, uint256 _amount);

    /// @dev Emitted when togglePerpetual function is successfully called
    event LogTogglePerpetual(address indexed _contractAddress, bool indexed _isPerpetual);

    /// @dev Checks if msg.sender is the minter
    modifier onlyMinter() {
        require(_msgSender() == minter, "!minter");
        _;
    }

    /// @dev Initialize RealEstateNFT
    /// @param _baseUri Base URI for the offchain NFT metadata
    /// @param _admin Address with contract administration privileges
    /// @param _owner EOA to be used as OpenSea collection admin
    constructor(
        string memory _baseUri,
        address _admin,
        address _owner
    ) RoyalERC1155(_baseUri, _admin, _owner) {}

    /// @notice Returns the name of the RealEstateERC1155 contract
    function name() external pure returns (string memory) {
        return "Fractional Real Estate NFT";
    }

    /// @notice Returns the symbol of the RealEstateERC1155 contract
    function symbol() external pure returns (string memory) {
        return "reNFT";
    }

    /// @notice Returns the URI for the given reNFT collection
    /// @param _id Collection ID
    /// @return Concatenated BaseUri and collectionId
    function uri(uint256 _id) public view override returns (string memory) {
        require(exists(_id), "Non-existent collection id");
        return string(abi.encodePacked(super.uri(_id), Strings.toString(_id)));
    }

    /// @notice Whether an account has expired and are elligible for liquidation
    /// @param _id Collection ID
    /// @param _account Account address
    function accountExpired(uint256 _id, address _account) public view returns (bool) {
        return !isPerpetual[_account] && block.timestamp >= accountExpirationTime[_id][_account];
    }

    /// @notice Check if an liquidation can be performed
    /// @param _id Collection ID
    /// @param _account Account address
    function isLiquidable(uint256 _id, address _account) public view returns (bool) {
        return liquidator != address(0) && accountExpired(_id, _account);
    }

    /// @dev Set new minter role
    /// @param _minter New minter address
    function setMinter(address _minter) external onlyAdmin {
        require(minter != _minter, "Same minter");
        minter = _minter;
        emit NewMinter(_minter);
    }

    /// @dev Set new burner role
    /// @param _burner New burner address
    function setBurner(address _burner) external onlyAdmin {
        require(burner != _burner, "Same burner");
        burner = _burner;
        emit NewBurner(_burner);
    }

    /// @dev Set new liquidator role
    /// @param _liquidator New liquidator address
    function setLiquidator(address _liquidator) external onlyAdmin {
        require(liquidator != _liquidator, "Same liquidator");
        liquidator = _liquidator;
    }

    /// @dev Sets the metadata for a new reNFT collection
    /// @dev Requires Minter role
    /// @param _id Collection ID
    /// @param _name New collection name
    /// @param _symbol New collection symbol
    /// @param _renovationTime The amount of time an user is required to check-in
    function setCollectionMetadata(
        uint256 _id,
        string memory _name,
        string memory _symbol,
        uint256 _renovationTime
    ) external onlyMinter {
        require(_msgSender() == minter, "!minter");
        require(!_metadataInitialized.get(_id), "metadataInitialized");

        collectionName[_id] = _name;
        collectionSymbol[_id] = _symbol;
        collectionRenovationTime[_id] = _renovationTime;
        _metadataInitialized.set(_id);
        emit SetCollectionMetadata(_id, _name, _symbol, _renovationTime);
    }

    /// @dev Toggle renovation requirements for a contract
    /// @param _contractAddress Address of the contract to toggle renovation
    /// @param _isPerpetual Whether to disable or enable renovation
    function togglePerpetual(address _contractAddress, bool _isPerpetual) external onlyAdmin {
        require(_contractAddress.isContract(), "Only contracts allowed to be perpetual");
        isPerpetual[_contractAddress] = _isPerpetual;
        emit LogTogglePerpetual(_contractAddress, _isPerpetual);
    }

    /// @dev Mint new reNFT tokens
    /// @dev Requires Minter role
    /// @param _id Collection ID
    /// @param _to Address to transfer minted tokens
    /// @param _amount Amount to mint
    function mint(
        uint256 _id,
        address _to,
        uint256 _amount
    ) external onlyMinter {
        require(_metadataInitialized.get(_id), "!metadataInitialized");
        if (totalSupply(_id) == 0) {
            uint256 currentId_ = _currentId.current();
            require(currentId_ == 0 || totalSupply(currentId_ - 1) > 0, "IDs should be sequential");
            _currentId.increment();
        }
        _mint(_to, _id, _amount, bytes(""));
        uint256 updatedExpirationTime = block.timestamp + collectionRenovationTime[_id];
        accountExpirationTime[_id][_to] = updatedExpirationTime;
        emit RenovationTimeUpdated(_id, _to, block.timestamp, updatedExpirationTime);
        emit RealEstateNFTMinted(_id, _msgSender(), _to, _amount);
    }

    /// @dev Allow the liquidator to take custody over expired accounts' tokens
    /// @param _id Collection ID
    /// @param _account Account address to liquidate tokens from
    /// @param _data Additional data requirements in case liquidator is a contract
    function takeCustody(
        uint256 _id,
        address _account,
        bytes memory _data
    ) external {
        require(_msgSender() == liquidator && isLiquidable(_id, _account), "Liquidation denied");
        _safeTransferFrom(_account, _msgSender(), _id, balanceOf(_msgSender(), _id), _data);
    }

    /// @notice Renovate expiration time (proving the account is active)
    /// @param _id Collection ID
    function renovateExpirationTime(uint256 _id) public {
        require(balanceOf(_msgSender(), _id) > 0, "No balance");
        uint256 updatedExpirationTime = block.timestamp + collectionRenovationTime[_id];
        accountExpirationTime[_id][_msgSender()] = updatedExpirationTime;
        emit RenovationTimeUpdated(_id, _msgSender(), block.timestamp, updatedExpirationTime);
    }

    /// @notice Renovate expiration time for all collections the user owns tokens
    function renovateAll() external {
        for (uint256 id = 0; id < _currentId.current(); id++) {
            if (balanceOf(_msgSender(), id) > 0) renovateExpirationTime(id);
        }
    }

    /// @dev Burns own tokens
    /// @dev Requires Burner role
    /// @param _id Collection ID
    /// @param _amount Amount of tokens to burn
    function burn(uint256 _id, uint256 _amount) external {
        require(_msgSender() == burner, "!burner");
        _burn(_msgSender(), _id, _amount);
    }
}
