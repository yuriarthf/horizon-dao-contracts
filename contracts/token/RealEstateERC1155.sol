// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { IERC1155MetadataURIUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/IERC1155MetadataURIUpgradeable.sol";
import { BitMapsUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/structs/BitMapsUpgradeable.sol";
import { CountersUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import { StringsUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import { AddressUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import { RoyalERC1155Upgradeable } from "./RoyalERC1155Upgradeable.sol";

/// @title Real Estate NFT
/// @author Yuri Fernandes (HorizonDAO)
/// @notice Used to Tokenize and Fractionate Real Estate
/// @notice Only minter can mint tokens and set token metadata
/// @notice New tokens should be minted by incrementing the tokenId by 1
contract RealEstateERC1155 is RoyalERC1155Upgradeable {
    using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using StringsUpgradeable for uint256;
    using AddressUpgradeable for address;

    /// @dev Address of the minter: Can execute mint function
    address public minter;

    /// @dev Address of the burner: Can execute burning functions
    address public burner;

    /// @dev Current value shows the next available token ID
    CountersUpgradeable.Counter private _currentId;

    /// @dev Emitted when a new minter is set
    event SetMinter(address indexed _by, address indexed _minter);

    /// @dev Emitted when a new burner is set
    event SetBurner(address indexed _by, address indexed _burner);

    /// @dev Emitted when new reNFTs are minted
    event RealEstateNFTMinted(uint256 indexed _id, address indexed _minter, address indexed _to, uint256 _amount);

    /// @dev Emitted when reNFTs are burned
    event RealEstateNFTBurned(uint256 indexed _id, address indexed _burner, uint256 _amount);

    /// @dev Initialize RealEstateNFT
    /// @param _uri Standard (fallback) URI for the offchain NFT metadata
    /// @param _admin Address with contract administration privileges
    /// @param _owner EOA to be used as OpenSea token admin
    function initialize(string memory _uri, address _admin, address _owner) public initializer {
        __RoyalERC1155_init(_uri, _admin, _owner);
    }

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
    /// @param _id Token ID
    /// @param _to Address to transfer minted tokens
    /// @param _amount Amount to mint
    function mint(uint256 _id, address _to, uint256 _amount) external {
        require(_msgSender() == minter, "!minter");
        if (totalSupply(_id) == 0) {
            require(_id == 0 || totalSupply(_id - 1) > 0, "IDs should be sequential");
            _currentId.increment();
        }
        _mint(_to, _id, _amount, bytes(""));
        emit RealEstateNFTMinted(_id, _msgSender(), _to, _amount);
    }

    /// @dev Burns own tokens
    /// @dev Requires Burner role
    /// @param _id Token ID
    /// @param _amount Amount of tokens to burn
    function burn(uint256 _id, uint256 _amount) external {
        require(_msgSender() == burner, "!burner");
        _burn(_msgSender(), _id, _amount);
        emit RealEstateNFTBurned(_id, _msgSender(), _amount);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[47] private __gap;
}
