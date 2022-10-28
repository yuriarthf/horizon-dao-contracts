// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { IERC1155MetadataURI } from "@openzeppelin/contracts/token/ERC1155/extensions/IERC1155MetadataURI.sol";
import { BitMaps } from "@openzeppelin/contracts/utils/structs/BitMaps.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { RoyalERC1155 } from "./RoyalERC1155.sol";

contract RealEstateERC1155 is RoyalERC1155 {
    using BitMaps for BitMaps.BitMap;
    using Strings for uint256;

    // TODO: Move to IRealEstateERC1155.sol
    enum TokenType {
        NOT_SET,
        SPACE,
        LAND
    }

    /// @dev Address of the minter: Can execute mint function
    address public minter; // TODO: Will it be only one minter?

    /// @dev mapping (tokenId => tokenName)
    mapping(uint256 => string) public tokenName;

    /// @dev mapping (tokenId => tokenSymbol)
    mapping(uint256 => string) public tokenSymbol;

    /// @dev mapping (tokenId => tokenType)
    mapping(uint256 => TokenType) public tokenType;

    /// @dev mapping (tokenId => tokenMaxSupply)
    BitMaps.BitMap private _tokensClaimed;

    /// @dev mapping (tokenId => renovationTime)
    /// @dev When users renovate it's signature on reNFTs ownership
    /// users' expiration time will be extended to current_time + tokenRenovationTime
    mapping(uint256 => uint256) public tokenRenovationTime;

    /// @dev mapping (tokenId => account => expiration time)
    /// @dev Users' reNFTs can be put to auction after current_time >= accountExpirationTime,
    /// in order to avoid it, users should renovate it's expiration time
    mapping(uint256 => mapping(address => uint256)) public accountExpirationTime;

    /// @dev mapping (tokenId => isInitialized)
    /// @dev when a tokenId is initialized, it means it cannot change afterwards
    BitMaps.BitMap private _metadataInitialized;

    /// @dev Emitted when the renovation time of an user is updated (by itself)
    event RenovationTimeUpdated(uint256 indexed _id, address indexed _account, uint256 _updatedAt, uint256 _extendedTo);

    /// @dev Emitted when a new reNFT collection metadata is configured
    event SetTokenMetadata(
        uint256 indexed _id,
        TokenType indexed _tokenType,
        string _name,
        string _symbol,
        uint256 _renovationTime
    );

    /// @dev Emitted when a new minter is set
    event NewMinter(address indexed _minter);

    /// @dev Emitted when all IRO/IRRO pending tokens have been claimed
    event AllTokenClaimed(uint256 indexed _id, address indexed _minter, uint256 _timestamp);

    /// @dev Emitted when new reNFTs are minted
    event RealEstateNFTMinted(uint256 indexed _id, address indexed _minter, address indexed _to, uint256 _amount);

    /// @dev Emitted when an user burns all the supply of a reNFT (giving him rights to claim it's deed IRL)
    event RealEstateRedeemed(uint256 indexed _id, TokenType indexed _tokenType, address indexed _redeemer);

    /// @dev Checks if msg.sender is the minter
    modifier onlyMinter() {
        require(msg.sender == minter, "!minter");
        _;
    }

    constructor(string memory uri_, address _admin, address _fakeOwner) RoyalERC1155(uri_, _admin, _fakeOwner) {}

    /// @dev Returns the name of the RealEstateERC1155 contract
    function name() external pure returns (string memory) {
        return "Real Estate NFT";
    }

    /// @dev Returns the symbol of the RealEstateERC1155 contract
    function symbol() external pure returns (string memory) {
        return "reNFT";
    }

    /// @dev Returns the URI for the given reNFT collection
    /// @param _id Collection ID
    /// @return Concatenated BaseUri and tokenId
    function uri(uint256 _id) public view override(ERC1155, IERC1155MetadataURI) returns (string memory) {
        require(exists(_id), "ERC721Tradable#uri: NONEXISTENT_TOKEN");
        return string(abi.encodePacked(super.uri(_id), Strings.toString(_id)));
    }

    /// @dev Set new minter role
    /// @param _minter New minter address
    function setMinter(address _minter) external onlyAdmin {
        require(minter != _minter, "minter == _minter");
        minter = _minter;
        emit NewMinter(_minter);
    }

    /// @dev Sets the metadata for a new reNFT collection
    function setTokenMetadata(
        uint256 _id,
        string memory _name,
        string memory _symbol,
        TokenType _tokenType,
        uint256 _renovationTime
    ) external onlyMinter {
        require(!_metadataInitialized.get(_id), "metadataInitialized");
        require(_tokenType != TokenType.NOT_SET, "_tokenType == TokenType.NOT_SET");

        tokenName[_id] = _name;
        tokenSymbol[_id] = _symbol;
        tokenType[_id] = _tokenType;
        tokenRenovationTime[_id] = _renovationTime;
        _metadataInitialized.set(_id);
        emit SetTokenMetadata(_id, _tokenType, _name, _symbol, _renovationTime);
    }

    function markAsClaimed(uint256 _id) external onlyMinter {
        require(!_tokensClaimed.get(_id), "tokensClaimed");
        _tokensClaimed.set(_id);
        emit AllTokenClaimed(_id, msg.sender, block.timestamp);
    }

    function mint(address _to, uint256 _id, uint256 _amount) external onlyMinter {
        require(_metadataInitialized.get(_id), "!metadataInitialized");
        _mint(_to, _id, _amount, bytes(""));
        uint256 updatedExpirationTime = block.timestamp + tokenRenovationTime[_id];
        accountExpirationTime[_id][_to] = updatedExpirationTime;
        emit RenovationTimeUpdated(_id, _to, block.timestamp, updatedExpirationTime);
        emit RealEstateNFTMinted(_id, msg.sender, _to, _amount);
    }

    function redeemDeed(uint256 _id) external {
        require(_tokensClaimed.get(_id), "!tokensClaimed");
        uint256 userBalance = balanceOf(msg.sender, _id);
        require(userBalance == totalSupply(_id), "userBalance != totalSupply");
        _burn(msg.sender, _id, userBalance);
        emit RealEstateRedeemed(_id, tokenType[_id], msg.sender);
    }

    function renovateExpirationTime(uint256 _id) external {
        require(balanceOf(msg.sender, _id) > 0, "userBalance == 0");
        uint256 updatedExpirationTime = block.timestamp + tokenRenovationTime[_id];
        accountExpirationTime[_id][msg.sender] = updatedExpirationTime;
        emit RenovationTimeUpdated(_id, msg.sender, block.timestamp, updatedExpirationTime);
    }

    // TODO:
    // - Add royalties
    // - function to auction non-renovated users' reNFTs
}
