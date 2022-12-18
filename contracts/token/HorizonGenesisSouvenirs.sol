// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { EnforcedRoyaltiesERC1155 } from "./EnforcedRoyaltiesERC1155.sol";

/// @title Horizon Genesis Souvenirs
/// @author Yuri Fernandes (HorizonDAO)
/// @notice Collectable HorizonDAO Genesis Souvenirs
contract HorizonGenesisSouvenirs is EnforcedRoyaltiesERC1155 {
    using Counters for Counters.Counter;
    using Strings for uint256;

    /// @dev Used to keep track of the existent token IDs
    Counters.Counter private _nextTokenId;

    /// @dev mapping (tokenId => name)
    /// @dev Token names
    mapping(uint256 => string) private _name;

    /// @dev mapping (tokenId => description)
    /// @dev Token descriptions
    mapping(uint256 => string) private _description;

    /// @dev Emitted when a new token is minted
    event NewMint(
        uint256 indexed _id,
        address indexed _to,
        string indexed _name,
        string _descrition,
        uint256 _totalSupply
    );

    /// @dev Emitted when a new base image URI is set for the tokens
    event NewImageBaseUri(address indexed _admin, string _uri);

    /// @dev constructor to initialize PioneerPromoERC1155 contract
    /// @param _imageBaseUri Base image URI
    /// @param _admin Adminstrative address, can execute various configuration related functions
    /// @param _owner Should be an EOA, will have rights over OpenSea collection configuration
    constructor(
        string memory _imageBaseUri,
        address _admin,
        address _owner
    ) EnforcedRoyaltiesERC1155(_imageBaseUri, _admin, _owner) {
        require(_admin != address(0), "Admin should not be ZERO ADDRESS");
        emit NewImageBaseUri(_msgSender(), _imageBaseUri);
    }

    /// @dev Mint a new token collection
    /// @param _to Address to mint the supply to
    /// @param _totalSupply Total token supply
    /// @param name_ Name of the token collection
    /// @param description_ Description of the token collection
    function mintNextIdSupply(
        address _to,
        uint256 _totalSupply,
        string memory name_,
        string memory description_
    ) external onlyAdmin {
        uint256 tokenId = _nextTokenId.current();
        _name[tokenId] = name_;
        _description[tokenId] = description_;
        _mint(_to, tokenId, _totalSupply, "");
        _nextTokenId.increment();
        emit NewMint(tokenId, _to, name_, description_, _totalSupply);
    }

    /// @notice Returns the Base64 encoded metadata for a given token
    /// @param _id Token ID
    /// @return Base64 encoded metadata
    function uri(uint256 _id) public view override returns (string memory) {
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(metadata(_id)))));
    }

    /// @notice Returns the stringified metadata JSON for a given token
    /// @param _id Token ID
    /// @return Stringified metadata JSON
    function metadata(uint256 _id) public view returns (string memory) {
        string memory imageBaseUri_ = imageBaseURI(_id);
        return
            string(
                abi.encodePacked(
                    '{"name":"',
                    _name[_id],
                    '","description":"',
                    _description[_id],
                    '","image":"',
                    imageBaseUri_,
                    '"}'
                )
            );
    }

    /// @notice Get token name
    /// @param _id Token ID
    /// @return Token name
    function name(uint256 _id) external view returns (string memory) {
        require(_id < _nextTokenId.current(), "Non-existend token ID");
        return _name[_id];
    }

    /// @notice Get token description
    /// @param _id Token ID
    /// @return Token description
    function description(uint256 _id) external view returns (string memory) {
        require(_id < _nextTokenId.current(), "Non-existend token ID");
        return _description[_id];
    }

    /// @notice Get the image Base URI for a given token
    /// @param _id Token ID
    /// @return Image URI
    function imageBaseURI(uint256 _id) public view returns (string memory) {
        require(_id < _nextTokenId.current(), "Non-existend token ID");
        string memory uri_ = super.uri(uint256(0));
        require(keccak256(bytes(uri_)) != keccak256(""), "!baseURI");
        return string(abi.encodePacked(super.uri(uint256(0)), _id.toString()));
    }
}
