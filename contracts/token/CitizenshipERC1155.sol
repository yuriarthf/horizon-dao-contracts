// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { RoyalERC1155 } from "./RoyalERC1155.sol";

/// @title Horizon DAO Citizenship NFTs
/// @author Horizon DAO (Yuri Fernandes)
/// @notice Citizenship NFTs which will be added utility
///     during development of HorizonDAO protocol
contract CitizenshipERC1155 is RoyalERC1155 {
    using Strings for uint256;

    /// @dev Citizenship types
    enum Citizenship {
        BRONZE,
        SILVER,
        GOLD
    }

    /// @dev The maximum purchaseable supply
    ///     does not count with the whitelisted citizenship claims
    uint256 public constant PURCHASABLE_SUPPLY = 10550;

    /// @dev Represents 100% chance, there will be 3 Citizenship collection
    ///     with decreasing chances to be minted during purchases
    ///     the total chances should sum to MAX_CHANCE
    uint256 public constant MAX_CHANCE = 1_000;

    /// @dev The unit price to purchase a citizenship NFT from a random collection
    uint256 public immutable tokenUnitPrice;

    /// @dev Amount of NFTs that have been purchased so far
    uint256 public purchasedAmount;

    /// @dev Calculated pseudo-random number should fall in range to acquire a certain citizenship
    mapping(Citizenship => uint256) public thresholds;

    /// @dev Merkle root used to whitelist addresses to claim gold citizenship
    bytes32 public goldMerkleRoot;

    /// @dev Merkle root used to whitelist addresses to claim gold citizenshi
    bytes32 public silverMerkleRoot;

    /// @dev Used to mark a gold citizenship as claimed from a whitelisted address
    mapping(address => bool) public goldClaimed;

    /// @dev Used to mark a silver citizenship as claimed for a whitelisted address
    mapping(address => bool) public silverClaimed;

    /// @dev Emitted when gold merkle root is set (only possible one time)
    event GoldMerkleRootSet(address indexed _admin, bytes32 _root);

    /// @dev Emitted when silver merkle root is set (only possible one time)
    event SilverMerkleRootSet(address indexed _admin, bytes32 _root);

    /// @dev Emitted when a new base image URI is set for the collections
    event NewImageUri(address indexed _admin, string _uri);

    /// @dev Emitted when ethers are withdrawn from the contract
    event Withdrawal(address indexed _admin, address indexed _to, uint256 _amount);

    /// @dev Emitted when an amount of citizenship NFTs are claimed
    event CitizenshipClaimed(
        address indexed _by,
        Citizenship indexed _citizenship,
        bool indexed _isWhitelist,
        uint256 _amount
    );

    /// @dev constructor to initialize CitizenshipPromoERC1155 contract
    /// @param _imageUri Base image URI
    /// @param _admin Adminstrative address, can execute various configuration related functions
    /// @param _owner Should be an EOA, will have rights over OpenSea collection configuration
    /// @param _tokenUnitPrice Price per random NFT claim
    /// @param _chances Array with the chances of getting a citizenship for each collection
    constructor(
        string memory _imageUri,
        address _admin,
        address _owner,
        uint256 _tokenUnitPrice,
        uint256[3] memory _chances
    ) RoyalERC1155(_imageUri, _admin, _owner) {
        require(_admin != address(0), "!admin");
        for (uint8 i = 0; i < _chances.length; i++) {
            if (i > 0) {
                require(_chances[i - 1] >= _chances[i], "Invalid _chance array");
                thresholds[Citizenship(i)] += thresholds[Citizenship(i - 1)];
            }
            thresholds[Citizenship(i)] += _chances[i];
        }
        require(thresholds[Citizenship.GOLD] == MAX_CHANCE, "_chances sum should be MAX_CHANCE");
        tokenUnitPrice = _tokenUnitPrice;
        emit NewImageUri(msg.sender, _imageUri);
    }

    /// @dev Set Gold merkle root (whitelist for gold citizenship claims)
    /// @param _root Merkle root
    function setGoldMerkleRoot(bytes32 _root) external onlyAdmin {
        require(goldMerkleRoot == bytes32(0), "Merkle root already set");
        goldMerkleRoot = _root;
        emit GoldMerkleRootSet(msg.sender, _root);
    }

    /// @dev Set Silver merkle root (whitelist for gold citizenship claims)
    /// @param _root Merkle root
    function setSilverMerkleRoot(bytes32 _root) external onlyAdmin {
        require(silverMerkleRoot == bytes32(0), "Merkle root already set");
        silverMerkleRoot = _root;
        emit SilverMerkleRootSet(msg.sender, _root);
    }

    /// @dev Set new base image URI for collections
    /// @param _uri Base image URI
    function setImageBaseURI(string memory _uri) external onlyAdmin {
        _setURI(_uri);
        emit NewImageUri(msg.sender, _uri);
    }

    /// @dev Used for whitelisted gold citizenship claims
    /// @param _proof Merkle proof for the executing address
    function claimGold(bytes32[] memory _proof) external {
        require(MerkleProof.verify(_proof, goldMerkleRoot, keccak256(abi.encodePacked(msg.sender))), "Access Denied");
        require(!goldClaimed[msg.sender], "Already claimed");
        _mint(msg.sender, uint256(Citizenship.GOLD), 1, bytes(""));
        emit CitizenshipClaimed(msg.sender, Citizenship.GOLD, true, 1);
    }

    /// @dev Used for whitelisted silver citizenship claims
    /// @param _proof Merkle proof for the executing address
    function claimSilver(bytes32[] memory _proof) external {
        require(MerkleProof.verify(_proof, goldMerkleRoot, keccak256(abi.encodePacked(msg.sender))), "Access Denied");
        require(!goldClaimed[msg.sender], "Already claimed");
        _mint(msg.sender, uint256(Citizenship.GOLD), 1, bytes(""));
        emit CitizenshipClaimed(msg.sender, Citizenship.GOLD, true, 1);
    }

    /// @notice Purchase citizenship NFTs randomly from the 3 collections (Bronze, Silver and Gold)
    /// @param _amount Amount to purchase
    function purchase(uint256 _amount) external payable {
        uint256 totalPrice = _amount * tokenUnitPrice;
        require(msg.value >= totalPrice, "Not enough ethers");
        require(purchasedAmount + _amount <= PURCHASABLE_SUPPLY, "_amount is too big");
        uint256 magicValue = uint256(
            keccak256(abi.encodePacked(msg.sender, block.timestamp, _amount, purchasedAmount))
        );

        uint256 chance;
        uint256[3] memory amounts;
        for (uint256 i = 0; i < _amount; i++) {
            chance = magicValue % MAX_CHANCE;
            if (chance < thresholds[Citizenship.BRONZE]) ++amounts[0];
            else if (chance < thresholds[Citizenship.SILVER]) ++amounts[1];
            else ++amounts[2];
            magicValue = uint256(keccak256(abi.encodePacked(magicValue / MAX_CHANCE)));
        }

        for (uint8 i = 0; i < amounts.length; i++) {
            if (amounts[i] == 0) continue;
            _mint(msg.sender, i, amounts[i], bytes(""));
            emit CitizenshipClaimed(msg.sender, Citizenship(i), false, amounts[i]);
        }
        purchasedAmount += _amount;

        uint256 surplus = msg.value - totalPrice;
        if (surplus > 0) _sendValue(msg.sender, surplus);
    }

    /// @dev Withdraw all ethers from contract
    /// @param _to Address to send the funds
    function withdraw(address _to) external onlyAdmin {
        uint256 etherBalance = address(this).balance;
        require(etherBalance > 0, "No ethers to withdraw");
        _sendValue(_to, etherBalance);
        emit Withdrawal(msg.sender, _to, etherBalance);
    }

    /// @notice Returns the Base64 encoded metadata for a given collection
    /// @param _id Collection ID
    /// @return Base64 encoded metadata
    function uri(uint256 _id) public view override returns (string memory) {
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(collectionMetadata(_id)))));
    }

    /// @notice Returns the stringified metadata JSON for a given collection
    /// @param _id Collection ID
    /// @return Stringified metadata JSON
    function collectionMetadata(uint256 _id) public view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '{ "name": "',
                    collectionName(_id),
                    '", "description": "',
                    collectionDescription(_id),
                    '", "image": "',
                    imageURI(_id),
                    '" }'
                )
            );
    }

    /// @notice Get collection name
    /// @param _id Collection ID
    /// @return Collection name
    function collectionName(uint256 _id) public pure returns (string memory) {
        require(_id >= uint256(Citizenship.BRONZE) && _id <= uint256(Citizenship.GOLD), "Invalid token ID");
        if (_id == uint256(Citizenship.BRONZE)) return "Bronze Citizenship";
        if (_id == uint256(Citizenship.GOLD)) return "Silver Citizenship";
        return "Gold Citizenship";
    }

    /// @notice Get collection description
    /// @param _id Collection ID
    /// @return Collection description
    function collectionDescription(uint256 _id) public pure returns (string memory) {
        require(_id >= uint256(Citizenship.BRONZE) && _id <= uint256(Citizenship.GOLD), "Invalid token ID");
        if (_id == uint256(Citizenship.BRONZE)) return "";
        if (_id == uint256(Citizenship.GOLD)) return "";
        return "";
    }

    /// @notice Get the image URI for a given collection
    /// @param _id Collection ID
    /// @return Image URI
    function imageURI(uint256 _id) public view returns (string memory) {
        return string(abi.encodePacked(super.uri(uint256(0)), _id.toString()));
    }

    /// @dev Utility function to send an amount of ethers to a given address
    /// @param _to Address to send ethers
    /// @param _amount Amount of ethers to send
    function _sendValue(address _to, uint256 _amount) internal {
        (bool success, ) = _to.call{ value: _amount }("");
        require(success, "Failed sending ethers");
    }
}
