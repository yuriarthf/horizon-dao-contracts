// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { ERC1155Supply } from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IEIP2981 } from "../interfaces/IEIP2981.sol";

/// @title Royal ERC1155
/// @dev Supports EIP-2981 royalties on NFT secondary sales
///      Supports OpenSea contract metadata royalties
///      Introduces fake "owner" to support OpenSea collections
abstract contract RoyalERC1155 is IEIP2981, ERC1155Supply {
    /// @dev OpenSea expects NFTs to be "Ownable", that is having an "owner",
    ///      we introduce a fake "owner" here with no authority
    address public owner;

    /// @dev Address of the admin: Can set a new admin among other privileged roles
    address public admin;

    /// @notice Address to receive EIP-2981 royalties from secondary sales
    ///         see https://eips.ethereum.org/EIPS/eip-2981
    address public royaltyReceiver;

    /// @notice Percentage of token sale price to be used for EIP-2981 royalties from secondary sales
    ///         see https://eips.ethereum.org/EIPS/eip-2981
    /// @dev Has 2 decimal precision. E.g. a value of 500 would result in a 5% royalty fee
    uint16 public royaltyPercentage; // default OpenSea value is 750

    /// @notice Contract level metadata to define collection name, description, and royalty fees.
    ///         see https://docs.opensea.io/docs/contract-level-metadata
    /// @dev Should be overwritten by inheriting contracts. By default only includes royalty information
    string public contractURI;

    /// @dev Fired in setContractURI()
    /// @param _by an address which executed update
    /// @param _value new contractURI value
    event ContractURIUpdated(address indexed _by, string _value);

    /// @dev Fired in setRoyaltyInfo()
    /// @param _by an address which executed update
    /// @param _receiver new royaltyReceiver value
    /// @param _percentage new royaltyPercentage value
    event RoyaltyInfoUpdated(address indexed _by, address indexed _receiver, uint16 _percentage);

    /// @dev Fired in setOwner()
    /// @param _by an address which set the new "owner"
    /// @param _oldVal previous "owner" address
    /// @param _newVal new "owner" address
    event OwnerUpdated(address indexed _by, address indexed _oldVal, address indexed _newVal);

    /// @dev Emitted when a new admin is set
    event NewAdmin(address indexed _admin);

    /// @dev Checks if msg.sender is the admin
    modifier onlyAdmin() {
        require(msg.sender == admin, "!admin");
        _;
    }

    constructor(string memory uri_, address _admin, address _owner) ERC1155(uri_) {
        // initialize owner as the "_owner", necessary for OpenSea
        owner = _owner;

        // set contract admin
        admin = _admin;
        emit NewAdmin(_admin);
    }

    /// @dev Set new admin role
    /// @param _admin New admin address
    function setAdmin(address _admin) external onlyAdmin {
        require(admin != _admin, "admin == _admin");
        admin = _admin;
        emit NewAdmin(_admin);
    }

    /// @dev Restricted access function which updates the contract URI
    /// @param _contractURI new contract URI to set
    function setContractURI(string memory _contractURI) public virtual onlyAdmin {
        // update the contract URI
        contractURI = _contractURI;

        // emit an event first
        emit ContractURIUpdated(msg.sender, _contractURI);
    }

    /// @notice EIP-2981 function to calculate royalties for sales in secondary marketplaces.
    ///         see https://eips.ethereum.org/EIPS/eip-2981
    /// @param _salePrice the price (in any unit, .e.g wei, ERC20 token, et.c.) of the token to be sold
    /// @return receiver the royalty receiver
    /// @return royaltyAmount royalty amount in the same unit as _salePrice
    function royaltyInfo(uint256, uint256 _salePrice)
        external
        view
        virtual
        override
        returns (address receiver, uint256 royaltyAmount)
    {
        // simply calculate the values and return the result
        return (royaltyReceiver, (_salePrice * royaltyPercentage) / 100_00);
    }

    /// @dev Restricted access function which updates the royalty info
    /// @param _royaltyReceiver new royalty receiver to set
    /// @param _royaltyPercentage new royalty percentage to set
    function setRoyaltyInfo(address _royaltyReceiver, uint16 _royaltyPercentage) public virtual onlyAdmin {
        // verify royalty percentage is zero if receiver is also zero
        require(_royaltyReceiver != address(0) || _royaltyPercentage == 0, "invalid receiver");

        // update the values
        royaltyReceiver = _royaltyReceiver;
        royaltyPercentage = _royaltyPercentage;

        // emit an event first
        emit RoyaltyInfoUpdated(msg.sender, _royaltyReceiver, _royaltyPercentage);
    }

    /// @notice Checks if the address supplied is an "owner" of the smart contract
    ///      Note: an "owner" doesn't have any authority on the smart contract and is "nominal"
    /// @return true if the caller is the current owner.
    function isOwner(address _addr) public view virtual returns (bool) {
        // just evaluate and return the result
        return _addr == owner;
    }

    /// @dev Restricted access function to set smart contract "owner"
    ///      Note: an "owner" set doesn't have any authority, and cannot even update "owner"
    /// @param _owner new "owner" of the smart contract
    function transferOwnership(address _owner) public virtual onlyAdmin {
        // update "owner"
        owner = _owner;

        // emit an event first - to log both old and new values
        emit OwnerUpdated(msg.sender, owner, _owner);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, IERC165) returns (bool) {
        // construct the interface support from EIP-2981 and super interfaces
        return interfaceId == type(IEIP2981).interfaceId || super.supportsInterface(interfaceId);
    }
}
