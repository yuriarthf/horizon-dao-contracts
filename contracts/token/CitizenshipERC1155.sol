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

    /// @dev Total number of tokens that can be purchased
    uint256 public constant PURCHASABLE_SUPPLY = 10406;

    /// @dev How many tokens can be purchased during Whitelisted sale
    uint256 public constant WHITELIST_MAX_PURCHASES = 1000;

    /// @dev How many tokens whitelisted users can purchase
    uint256 public constant WHITELIST_PURCHASE_PER_ADDRESS = 2;

    /// @dev Maximum amount of tokens users can get from private claim
    uint256 public constant PRIVATE_MAX_CLAIMS = 44;

    /// @dev Total claimable amount of tokens through airdrops
    uint256 public constant AIRDROP_MAX_CLAIMS = 100;

    /// @dev How many Gold citizenships a user can get from private claim
    uint256 public constant PRIVATE_CLAIM_GOLD = 1;

    /// @dev How many Silver citizenships a private sale user can claim
    uint256 public constant PRIVATE_CLAIM_SILVER = 10;

    /// @dev Represents 100% chance, there will be 3 Citizenship collection
    ///     with decreasing chances to be minted during purchases
    ///     the total chances should sum to MAX_CHANCE
    uint256 public constant MAX_CHANCE = 1_000;

    /// @dev Unit prie of tokens for Whitelisted sale
    uint256 public immutable whitelistTokenUnitPrice;

    /// @dev Unit price of tokens for Public sale
    uint256 public immutable publicTokenUnitPrice;

    /// @dev Amount of NFTs that have been purchased so far
    uint256 public purchasedAmount;

    /// @dev Calculated pseudo-random number should fall in range to acquire a certain citizenship
    mapping(Citizenship => uint256) public thresholds;

    /// @dev Private Merkle Root (can be set once)
    bytes32 public privateMerkleRoot;

    /// @dev Whitelist Merkle Root (can be set once)
    bytes32 public whitelistMerkleRoot;

    /// @dev Airdrop Merkle Root (can be set multiple times)
    bytes32 public airdropMerkleRoot;

    /// @dev How many tokens users have claimed during private sale
    mapping(address => bool) public userPrivateClaimed;

    /// @dev How many tokens the whitelisted users have claimed
    mapping(address => uint256) public userWhitelistPurchasedAmount;

    /// @dev Which Airdrop an user has participated
    mapping(address => uint256) public userAirdropNonce;

    /// @dev Nonce of the current airdrop Merkle Tree
    uint256 public airdropNonce;

    /// @dev Amount of Airdrop tokens claimed
    uint256 public airdropClaimed;

    /// @dev When the Public sale will begin (if zero, means sale has not been initialized)
    uint256 public publicSaleStartTime;

    /// @dev Emitted when Private Merkle Root is set
    event PrivateMerkleRootSet(address indexed _admin, bytes32 _root);

    /// @dev Emitted when Sale is initialized
    event SaleInitialized(address indexed _admin, bytes32 _whitelistMerkleRoot, uint256 _publicSaleStartTime);

    /// @dev Emitted when the Airdrop Merkle Root is set
    event AirdropMerkleRootSet(address indexed _admin, uint256 indexed _airdropNonce, bytes32 _root);

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
    /// @param _publicTokenUnitPrice Price per token for Public Sale
    /// @param _whitelistTokenUnitPrice Price per token for Whitelisted Sale
    /// @param _chances Array with the chances of getting a citizenship for each collection
    constructor(
        string memory _imageUri,
        address _admin,
        address _owner,
        uint256 _publicTokenUnitPrice,
        uint256 _whitelistTokenUnitPrice,
        uint256[3] memory _chances
    ) RoyalERC1155(_imageUri, _admin, _owner) {
        require(_admin != address(0), "!admin");
        require(_whitelistTokenUnitPrice < _publicTokenUnitPrice, "No discount applied");
        for (uint8 i = 0; i < _chances.length; i++) {
            if (i > 0) {
                require(_chances[i - 1] >= _chances[i], "Invalid _chance array");
                thresholds[Citizenship(i)] += thresholds[Citizenship(i - 1)];
            }
            thresholds[Citizenship(i)] += _chances[i];
        }
        require(thresholds[Citizenship.GOLD] == MAX_CHANCE, "_chances sum should be MAX_CHANCE");
        publicTokenUnitPrice = _publicTokenUnitPrice;
        whitelistTokenUnitPrice = _whitelistTokenUnitPrice;
        emit NewImageUri(msg.sender, _imageUri);
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

    /// @notice Whether the sale has been initialized
    function saleInitialized() public view returns (bool) {
        return whitelistMerkleRoot != bytes32(0);
    }

    /// @notice Whether public sale started
    function publicSaleStarted() public view returns (bool) {
        return saleInitialized() && block.timestamp >= publicSaleStartTime;
    }

    /// @dev Initialize sale (first whitelisted address, then public sale begins)
    /// @param _whitelistMerkleRoot Whitelist Merkle Root
    /// @param _publicSaleOffset Amount of time that will take for the Public sale to begin
    function initializeSale(bytes32 _whitelistMerkleRoot, uint256 _publicSaleOffset) external onlyAdmin {
        require(!saleInitialized(), "Merkle root already set");
        require(_whitelistMerkleRoot != bytes32(0), "Invalid Merkle root");
        whitelistMerkleRoot = _whitelistMerkleRoot;
        publicSaleStartTime = block.timestamp + _publicSaleOffset;
        emit SaleInitialized(msg.sender, _whitelistMerkleRoot, block.timestamp + _publicSaleOffset);
    }

    /// @dev Set Private claiming merkle root (only once)
    /// @param _root Private Merkle Root
    function setPrivateRoot(bytes32 _root) external onlyAdmin {
        require(privateMerkleRoot == bytes32(0), "Merkle root already set");
        privateMerkleRoot = _root;
        emit PrivateMerkleRootSet(msg.sender, _root);
    }

    /// @dev Set Airdrop merkle root (multiple times)
    /// @param _root Airdrop Merkle Root
    function setAirdropRoot(bytes32 _root) external onlyAdmin {
        require(airdropClaimed < AIRDROP_MAX_CLAIMS, "!airdrop");
        airdropMerkleRoot = _root;
        emit AirdropMerkleRootSet(msg.sender, ++airdropNonce, _root);
    }

    /// @dev Set new base image URI for collections
    /// @param _uri Base image URI
    function setImageBaseURI(string memory _uri) external onlyAdmin {
        _setURI(_uri);
        emit NewImageUri(msg.sender, _uri);
    }

    /// @notice Claim private whitelisted tokens
    /// @param _proof Private Merkle Proof
    function privateClaim(bytes32[] memory _proof) external {
        require(MerkleProof.verify(_proof, privateMerkleRoot, keccak256(abi.encodePacked(msg.sender))), "!root");
        require(!userPrivateClaimed[msg.sender], "claimed");
        _mint(msg.sender, uint256(Citizenship.GOLD), PRIVATE_CLAIM_GOLD, bytes(""));
        _mint(msg.sender, uint256(Citizenship.SILVER), PRIVATE_CLAIM_SILVER, bytes(""));
        userPrivateClaimed[msg.sender] = true;
        emit CitizenshipClaimed(msg.sender, Citizenship.GOLD, false, PRIVATE_CLAIM_GOLD);
        emit CitizenshipClaimed(msg.sender, Citizenship.SILVER, false, PRIVATE_CLAIM_SILVER);
    }

    /// @notice Purchase whilelisted tokens (maximum amount: WHITELIST_PURCHASE_PER_ADDRESS)
    /// @param _amount Amount to purchase
    /// @param _proof Whitelist Merkle Proof
    function whitelistPurchase(uint256 _amount, bytes32[] memory _proof) external payable {
        require(whitelistMerkleRoot != bytes32(0), "!initialized");
        require(MerkleProof.verify(_proof, whitelistMerkleRoot, keccak256(abi.encodePacked(msg.sender))));
        require(purchasedAmount + _amount <= PURCHASABLE_SUPPLY, "!purchase");
        require(
            userWhitelistPurchasedAmount[msg.sender] + _amount <= WHITELIST_PURCHASE_PER_ADDRESS,
            "Maximum amount purchased"
        );
        _processPurchaseRequest(whitelistTokenUnitPrice, _amount);
        userWhitelistPurchasedAmount[msg.sender] += _amount;
        purchasedAmount += _amount;
    }

    /// @notice Purchase citizenship NFTs randomly from the 3 collections (Bronze, Silver and Gold)
    /// @param _amount Amount to purchase
    function publicPurchase(uint256 _amount) external payable {
        require(publicSaleStarted(), "!start");
        require(purchasedAmount + _amount <= PURCHASABLE_SUPPLY, "!purchase");
        _processPurchaseRequest(publicTokenUnitPrice, _amount);
        purchasedAmount += _amount;
    }

    /// @notice Claim airdrop
    /// @param _amount Amount to claim
    /// @param _proof Airdrop Merkle Proof
    function claimAirdrop(uint256 _amount, bytes32[] memory _proof) external {
        require(
            MerkleProof.verify(_proof, airdropMerkleRoot, keccak256(abi.encodePacked(msg.sender, _amount))),
            "!merkleRoot"
        );
        require(airdropClaimed + _amount < AIRDROP_MAX_CLAIMS, "!airdrop");
        uint256 airdropNonce_ = airdropNonce;
        require(userAirdropNonce[msg.sender] < airdropNonce_, "!userNonce");
        _processPurchaseRequest(0, _amount);
        airdropClaimed += _amount;
        userAirdropNonce[msg.sender] = airdropNonce_;
    }

    /// @dev Withdraw all ethers from contract
    /// @param _to Address to send the funds
    function withdraw(address _to) external onlyAdmin {
        uint256 etherBalance = address(this).balance;
        require(etherBalance > 0, "No ethers to withdraw");
        _sendValue(_to, etherBalance);
        emit Withdrawal(msg.sender, _to, etherBalance);
    }

    /// @dev Utility function to send an amount of ethers to a given address
    /// @param _to Address to send ethers
    /// @param _amount Amount of ethers to send
    function _sendValue(address _to, uint256 _amount) internal {
        (bool success, ) = _to.call{ value: _amount }("");
        require(success, "Failed sending ethers");
    }

    /// @dev Process purchase payment and minting
    /// @param _tokenUnitPrice Unit price of the token
    /// @param _amount Amount of tokens to buy
    function _processPurchaseRequest(uint256 _tokenUnitPrice, uint256 _amount) internal {
        uint256 totalPrice = _amount * _tokenUnitPrice;
        require(msg.value >= totalPrice, "Not enough ethers");
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
        uint256 surplus = msg.value - totalPrice;
        if (surplus > 0) _sendValue(msg.sender, surplus);
    }
}
