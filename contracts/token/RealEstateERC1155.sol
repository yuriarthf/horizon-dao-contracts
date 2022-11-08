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

    /// @dev Current value shows the next available token ID
    Counters.Counter private _currentId;

    /// @dev Emitted when a new minter is set
    event SetMinter(address indexed _by, address indexed _minter);

    /// @dev Emitted when a new burner is set
    event SetBurner(address indexed _by, address indexed _burner);

    /// @dev Emitted when new reNFTs are minted
    event RealEstateNFTMinted(uint256 indexed _tokenId, address indexed _minter, address indexed _to, uint256 _amount);

    /// @dev Emitted when reNFTs are burned
    event RealEstateNFTBurned(uint256 indexed _tokenId, address indexed _burner, uint256 _amount);

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

    /// @notice Returns the ID of the next available reNFT
    function nextRealEstateId() external view returns (uint256) {
        return _currentId.current();
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

    /// @dev Mint new reNFT tokens
    /// @dev Requires Minter role
    /// @param _tokenId Token ID
    /// @param _to Address to transfer minted tokens
    /// @param _amount Amount to mint
    function mint(uint256 _tokenId, address _to, uint256 _amount) external {
        require(_msgSender() == minter, "!minter");
        if (totalSupply(_tokenId) == 0) {
            require(_tokenId == 0 || totalSupply(_tokenId - 1) > 0, "IDs should be sequential");
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
        emit RealEstateNFTBurned(_tokenId, _msgSender(), _amount);
    }
}
