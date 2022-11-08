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
/// @notice Only minter can mint tokens and set token metadata
/// @notice New tokens should be minted by incrementing the tokenId by 1
contract RealEstateERC1155 is RoyalERC1155 {
    using BitMaps for BitMaps.BitMap;
    using Counters for Counters.Counter;
    using Strings for uint256;
    using Address for address;

    /// @dev Address of the minter: Can execute mint function
    address public minter;

    /// @dev Address of the burner: Can execute burning functions
    address public burner;

    /// @dev mapping (tokenId => tokenName)
    mapping(uint256 => string) public tokenName;

    /// @dev mapping (tokenId => tokenSymbol)
    mapping(uint256 => string) public tokenSymbol;

    /// @dev mapping (tokenId => isInitialized)
    /// @dev when a tokenId is initialized, it means it cannot change afterwards
    BitMaps.BitMap private _metadataInitialized;

    /// @dev Current value shows the next available token ID
    Counters.Counter private _currentId;

    /// @dev Emitted when a new reNFT token metadata is configured
    event SetTokenMetadata(uint256 indexed _id, string _name, string _symbol);

    /// @dev Emitted when a new minter is set
    event SetMinter(address indexed _by, address indexed _minter);

    /// @dev Emitted when a new burner is set
    event SetBurner(address indexed _by, address indexed _burner);

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
    /// @param _owner EOA to be used as OpenSea token admin
    constructor(string memory _baseUri, address _admin, address _owner) RoyalERC1155(_baseUri, _admin, _owner) {}

    /// @notice Returns the name of the RealEstateERC1155 contract
    function name() external pure returns (string memory) {
        return "Real Estate NFT";
    }

    /// @notice Returns the symbol of the RealEstateERC1155 contract
    function symbol() external pure returns (string memory) {
        return "reNFT";
    }

    /// @dev Set new minter role
    /// @param _minter New minter address
    function setMinter(address _minter) external onlyAdmin {
        require(minter != _minter, "Same minter");
        minter = _minter;
        emit SetMinter(_msgSender(), _minter);
    }

    /// @dev Set new burner role
    /// @param _burner New burner address
    function setBurner(address _burner) external onlyAdmin {
        require(burner != _burner, "Same burner");
        burner = _burner;
        emit SetBurner(_msgSender(), _burner);
    }

    /// @dev Sets the metadata for a new reNFT token
    /// @dev Requires Minter role
    /// @param _tokenId Token ID
    /// @param _name New token name
    /// @param _symbol New token symbol
    function setTokenMetadata(uint256 _tokenId, string memory _name, string memory _symbol) external onlyMinter {
        require(_msgSender() == minter, "!minter");
        require(!_metadataInitialized.get(_tokenId), "metadataInitialized");

        tokenName[_tokenId] = _name;
        tokenSymbol[_tokenId] = _symbol;
        _metadataInitialized.set(_tokenId);
        emit SetTokenMetadata(_tokenId, _name, _symbol);
    }

    /// @dev Mint new reNFT tokens
    /// @dev Requires Minter role
    /// @param _tokenId Token ID
    /// @param _to Address to transfer minted tokens
    /// @param _amount Amount to mint
    function mint(uint256 _tokenId, address _to, uint256 _amount) external onlyMinter {
        require(_metadataInitialized.get(_tokenId), "!metadataInitialized");
        if (totalSupply(_tokenId) == 0) {
            uint256 currentId_ = _currentId.current();
            require(currentId_ == 0 || totalSupply(currentId_ - 1) > 0, "IDs should be sequential");
            _currentId.increment();
        }
        _mint(_to, _tokenId, _amount, bytes(""));
        emit RealEstateNFTMinted(_tokenId, _msgSender(), _to, _amount);
    }

    /// @dev Burns own tokens
    /// @dev Requires Burner role
    /// @param _tokenId Token ID
    /// @param _amount Amount of tokens to burn
    function burn(uint256 _tokenId, uint256 _amount) external {
        require(_msgSender() == burner, "!burner");
        _burn(_msgSender(), _tokenId, _amount);
    }
}
