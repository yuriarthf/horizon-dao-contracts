// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { IERC1155MetadataURI } from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import { BitMaps } from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { RoyalERC1155 } from "./RoyalERC1155.sol";

/// @title Real Estate NFT
/// @author Yuri Fernandes (HorizonDAO)
/// @notice Used to Tokenize and Fractionate Real Estate
/// @notice Users are required to renovate (check-in) after a certain amount of time
///     or their assets can be liquidated (necessary since reNFT holders can claim deeds if a buyout occur)
/// @notice Only a predefined minter can mint tokens and on a incremental order
contract RealEstateERC1155 is RoyalERC1155 {
    using BitMaps for BitMaps.BitMap;
    using Counters for Counters.Counter;
    using Strings for uint256;
    using Address for address;

    /// @dev Address of the minter: Can execute mint function
    address public minter;

    /// @dev Address of the burner: Can execute burning functions
    address public burner;

    /// @dev mapping (collectionId => collectionName)
    mapping(uint256 => string) public collectionName;

    /// @dev mapping (collectionId => collectionSymbol)
    mapping(uint256 => string) public collectionSymbol;

    /// @dev mapping (tokenId => isInitialized)
    /// @dev when a tokenId is initialized, it means it cannot change afterwards
    BitMaps.BitMap private _metadataInitialized;

    /// @dev Current value shows the next available collection ID
    Counters.Counter private _currentId;

    /// @dev Emitted when a new reNFT collection metadata is configured
    event SetCollectionMetadata(uint256 indexed _id, string _name, string _symbol);

    /// @dev Emitted when a new minter is set
    event NewMinter(address indexed _minter);

    /// @dev Emitted when a new burner is set
    event NewBurner(address indexed _burner);

    /// @dev Emitted when new reNFTs are minted
    event RealEstateNFTMinted(uint256 indexed _id, address indexed _minter, address indexed _to, uint256 _amount);

    /// @dev Checks if msg.sender is the minter
    modifier onlyMinter() {
        require(_msgSender() == minter, "!minter");
        _;
    }

    /// @dev Initialize RealEstateNFT
    /// @param _baseUri Base URI for the offchain NFT metadata
    /// @param _admin Address with contract administration privileges
    /// @param _owner EOA to be used as OpenSea collection admin
    constructor(string memory _baseUri, address _admin, address _owner) RoyalERC1155(_baseUri, _admin, _owner) {}

    /// @notice Returns the name of the RealEstateERC1155 contract
    function name() external pure returns (string memory) {
        return "Real Estate NFT";
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

    /// @dev Sets the metadata for a new reNFT collection
    /// @dev Requires Minter role
    /// @param _id Collection ID
    /// @param _name New collection name
    /// @param _symbol New collection symbol
    function setCollectionMetadata(uint256 _id, string memory _name, string memory _symbol) external onlyMinter {
        require(_msgSender() == minter, "!minter");
        require(!_metadataInitialized.get(_id), "metadataInitialized");

        collectionName[_id] = _name;
        collectionSymbol[_id] = _symbol;
        _metadataInitialized.set(_id);
        emit SetCollectionMetadata(_id, _name, _symbol);
    }

    /// @dev Mint new reNFT tokens
    /// @dev Requires Minter role
    /// @param _id Collection ID
    /// @param _to Address to transfer minted tokens
    /// @param _amount Amount to mint
    function mint(uint256 _id, address _to, uint256 _amount) external onlyMinter {
        require(_metadataInitialized.get(_id), "!metadataInitialized");
        if (totalSupply(_id) == 0) {
            uint256 currentId_ = _currentId.current();
            require(currentId_ == 0 || totalSupply(currentId_ - 1) > 0, "IDs should be sequential");
            _currentId.increment();
        }
        _mint(_to, _id, _amount, bytes(""));
        emit RealEstateNFTMinted(_id, _msgSender(), _to, _amount);
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
