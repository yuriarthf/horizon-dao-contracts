// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC2981 } from "@openzeppelin/contracts/token/common/ERC2981.sol";
import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { IERC2981 } from "@openzeppelin/contracts/interfaces/IERC2981.sol";
import { SingleApprovableERC1155 } from "./SingleApprovableERC1155.sol";

/// @title Royal ERC1155
/// @dev Supports EIP-2981 royalties on NFT secondary sales
///      Supports OpenSea contract metadata royalties
///      Introduces fake "owner" to support OpenSea collections
abstract contract RoyalERC1155 is ERC2981, SingleApprovableERC1155 {
    /// @dev OpenSea expects NFTs to be "Ownable", that is having an "owner",
    ///      we introduce a fake "owner" here with no authority
    address public owner;

    /// @dev Address of the admin: Can set a new admin among other privileged roles
    address public admin;

    /// @notice Contract level metadata to define collection name, description, and royalty fees.
    ///         see https://docs.opensea.io/docs/contract-level-metadata
    /// @dev Should be overwritten by inheriting contracts. By default only includes royalty information
    string public contractURI;

    /// @dev Fired in setContractURI()
    /// @param _by an address which executed update
    /// @param _value new contractURI value
    event ContractURIUpdated(address indexed _by, string _value);

    /// @dev Fired in setOwner()
    /// @param _previousOwner previous "owner" address
    /// @param _newOwner new "owner" address
    event OwnershipTransferred(address indexed _previousOwner, address indexed _newOwner);

    /// @dev Fired in setDefaultRoyalty()
    /// @param _by Address that called the function
    /// @param _receiver Royalties receiver address
    /// @param _feeNumerator Fee in basis points
    event SetDefaultRoyalties(address indexed _by, address indexed _receiver, uint96 _feeNumerator);

    /// @dev Fired in setTokenRoyalty()
    /// @param _by Address that called the function
    /// @param _tokenId Token ID which had the royalties set
    /// @param _receiver Royalties receiver address
    /// @param _feeNumerator Fee in basis points
    event SetTokenRoyalty(
        address indexed _by,
        uint256 indexed _tokenId,
        address indexed _receiver,
        uint96 _feeNumerator
    );

    /// @dev Emitted when a new admin is set
    event NewAdmin(address indexed _admin);

    /// @dev Checks if msg.sender is the admin
    modifier onlyAdmin() {
        require(msg.sender == admin, "!admin");
        _;
    }

    /// @dev Initializes RoyalERC1155 contract
    /// @param uri_ Token URI
    /// @param _admin Address of the admin
    /// @param _owner Address with permissions on OpenSea
    constructor(string memory uri_, address _admin, address _owner) ERC1155(uri_) {
        // initialize owner as the "_owner", necessary for OpenSea
        _transferOwnership(_owner);

        // set contract admin
        admin = _admin;
        emit NewAdmin(_admin);
    }

    /// @notice The denominator of which will be used to calculate the fee (feeNumerator/feeDenominator)
    function feeDenominator() external pure returns (uint256) {
        return _feeDenominator();
    }

    /// @dev Set new admin role
    /// @param _admin New admin address
    function setAdmin(address _admin) external onlyAdmin {
        require(admin != _admin, "admin == _admin");
        admin = _admin;
        emit NewAdmin(_admin);
    }

    /// @notice Checks if the address supplied is an "owner" of the smart contract
    ///      Note: an "owner" doesn't have any authority on the smart contract and is "nominal"
    /// @return true if the caller is the current owner.
    function isOwner(address _addr) public view virtual returns (bool) {
        // just evaluate and return the result
        return _addr == owner;
    }

    /// @dev Set the default royalties info (for all token IDs)
    /// @param _receiver Address of the royalties receiver
    /// @param _feeNumerator Fee in basis points
    function setDefaultRoyalty(address _receiver, uint96 _feeNumerator) external onlyAdmin {
        _setDefaultRoyalty(_receiver, _feeNumerator);
        emit SetDefaultRoyalties(_msgSender(), _receiver, _feeNumerator);
    }

    /// @dev Set royalties info for a specific token ID
    /// @param _tokenId Token
    /// @param _receiver Address of the royalties receiver
    /// @param _feeNumerator Fee in basis points
    function setTokenRoyalty(uint256 _tokenId, address _receiver, uint96 _feeNumerator) external onlyAdmin {
        _setTokenRoyalty(_tokenId, _receiver, _feeNumerator);
        emit SetTokenRoyalty(_msgSender(), _tokenId, _receiver, _feeNumerator);
    }

    /// @dev Restricted access function which updates the contract URI
    /// @param _contractURI new contract URI to set
    function setContractURI(string memory _contractURI) public virtual onlyAdmin {
        // update the contract URI
        contractURI = _contractURI;

        // emit an event first
        emit ContractURIUpdated(msg.sender, _contractURI);
    }

    /// @dev Restricted access function to set smart contract "owner"
    ///      Note: an "owner" set doesn't have any authority, and cannot even update "owner"
    /// @param _owner new "owner" of the smart contract
    function transferOwnership(address _owner) public virtual onlyAdmin {
        _transferOwnership(_owner);
    }

    /**
     * @dev See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC1155, ERC2981) returns (bool) {
        return
            interfaceId == type(IERC2981).interfaceId ||
            ERC1155.supportsInterface(interfaceId) ||
            ERC2981.supportsInterface(interfaceId);
    }

    /// @dev Set the smart contract owner
    /// @param _owner new "owner" of the smart contract
    function _transferOwnership(address _owner) internal {
        // update "owner"
        address oldOwner = owner;
        owner = _owner;

        // emit an event first - to log both old and new values
        emit OwnershipTransferred(oldOwner, _owner);
    }
}
