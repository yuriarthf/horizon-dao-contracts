// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { RoyalERC1155 } from "./RoyalERC1155.sol";

/// @title HorizonDAO Pioneer NFT
/// @author Yuri Fernandes (HorizonDAO)
/// @notice NFTs owned by HorizonDAO pioneer members
/// @notice Holding these NFTs will accrue into various rewards
///     during HorizonDAO development, such as, for example Airdrops
contract PioneerERC1155 is RoyalERC1155 {
    using Strings for uint256;

    /// @dev Pioneer types
    enum Pioneer {
        BRONZE,
        SILVER,
        GOLD
    }

    /// @dev Total number of tokens that can be purchased
    uint256 public constant PURCHASABLE_SUPPLY = 10446;

    /// @dev How many tokens can be purchased during Whitelisted sale
    uint256 public constant WHITELIST_MAX_PURCHASES = 1000;

    /// @dev How many tokens whitelisted users can purchase
    uint256 public constant WHITELIST_PURCHASE_PER_ADDRESS = 10;

    /// @dev Maximum amount of tokens users can get from private claim
    uint256 public constant PRIVATE_MAX_CLAIMS = 4;

    /// @dev Total claimable amount of tokens through airdrops
    uint256 public constant AIRDROP_MAX_CLAIMS = 100;

    /// @dev How many Gold Pioneers a user can get from private claim
    uint256 public constant PRIVATE_CLAIM_GOLD = 1;

    /// @dev Represents 100% chance, there will be 3 Pioneer collection
    ///     with decreasing chances to be minted during purchases
    ///     the total chances should sum to MAX_CHANCE
    uint256 public constant MAX_CHANCE = 1_000;

    /// @dev Unit prie of tokens for Whitelisted sale
    uint256 public immutable whitelistTokenUnitPrice;

    /// @dev Unit price of tokens for Public sale
    uint256 public immutable publicTokenUnitPrice;

    /// @dev Amount of NFTs that have been purchased so far
    uint256 public purchasedAmount;

    /// @dev Calculated pseudo-random number should fall in range to acquire a certain Pioneer
    mapping(Pioneer => uint256) public thresholds;

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

    /// @dev Emitted when a PioneerNFT is purchased
    event PioneerClaim(address indexed _by, Pioneer indexed _Pioneer, uint256 _unitPrice, uint256 _amount);

    /// @dev Emitted when an amount of Pioneer NFTs are claimed
    event PrivateClaim(address indexed _by);

    /// @dev Emitted when tokens are purchased via whitelistPurchase function
    event WhitelistPurchase(address indexed _by, uint256 _amount);

    /// @dev Emitted when tokens are purchased via publicPurchase function
    event PublicPurchase(address indexed _by, uint256 _amount);

    /// @dev Emitted when
    event AirdropClaim(address indexed _by, uint256 _amount);

    /// @dev constructor to initialize PioneerPromoERC1155 contract
    /// @param _imageUri Base image URI
    /// @param _admin Adminstrative address, can execute various configuration related functions
    /// @param _owner Should be an EOA, will have rights over OpenSea collection configuration
    /// @param _publicTokenUnitPrice Price per token for Public Sale
    /// @param _whitelistTokenUnitPrice Price per token for Whitelisted Sale
    /// @param _chances Array with the chances of getting a Pioneer for each collection
    constructor(
        string memory _imageUri,
        address _admin,
        address _owner,
        uint256 _publicTokenUnitPrice,
        uint256 _whitelistTokenUnitPrice,
        uint256[3] memory _chances
    ) RoyalERC1155(_imageUri, _admin, _owner) {
        require(_admin != address(0), "Admin should not be ZERO ADDRESS");
        require(_whitelistTokenUnitPrice < _publicTokenUnitPrice, "No discount applied");
        for (uint8 i = 0; i < _chances.length; i++) {
            if (i > 0) {
                require(_chances[i - 1] >= _chances[i], "Invalid _chance array");
                thresholds[Pioneer(i)] += thresholds[Pioneer(i - 1)];
            }
            thresholds[Pioneer(i)] += _chances[i];
        }
        require(thresholds[Pioneer.GOLD] == MAX_CHANCE, "_chances sum should be MAX_CHANCE");
        publicTokenUnitPrice = _publicTokenUnitPrice;
        whitelistTokenUnitPrice = _whitelistTokenUnitPrice;
        emit NewImageUri(_msgSender(), _imageUri);
    }

    /// @notice Returns the Base64 encoded metadata for a given collection
    /// @param _id Collection ID
    /// @return Base64 encoded metadata
    function uri(uint256 _id) public view override returns (string memory) {
        require(_id <= uint256(Pioneer.GOLD), "Invalid collection ID");
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(collectionMetadata(_id)))));
    }

    /// @notice Returns the stringified metadata JSON for a given collection
    /// @param _id Collection ID
    /// @return Stringified metadata JSON
    function collectionMetadata(uint256 _id) public view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    '{"name":"',
                    collectionName(_id),
                    '","description":"',
                    collectionDescription(_id),
                    '","image":"',
                    imageURI(_id),
                    '"}'
                )
            );
    }

    /// @notice Get collection name
    /// @param _id Collection ID
    /// @return Collection name
    function collectionName(uint256 _id) public pure returns (string memory) {
        require(_id <= uint256(Pioneer.GOLD), "Invalid collection ID");
        if (_id == uint256(Pioneer.BRONZE)) return "Bronze Horizon Pioneer Badge";
        if (_id == uint256(Pioneer.SILVER)) return "Silver Horizon Pioneer Badge";
        return "Gold Horizon Pioneer Badge";
    }

    /// @notice Get collection description
    /// @param _id Collection ID
    /// @return Collection description
    function collectionDescription(uint256 _id) public pure returns (string memory) {
        require(_id <= uint256(Pioneer.GOLD), "Invalid collection ID");
        if (_id == uint256(Pioneer.BRONZE)) return "";
        if (_id == uint256(Pioneer.SILVER)) return "";
        return "";
    }

    /// @notice Get the image URI for a given collection
    /// @param _id Collection ID
    /// @return Image URI
    function imageURI(uint256 _id) public view returns (string memory) {
        string memory uri_ = super.uri(uint256(0));
        require(keccak256(bytes(uri_)) != keccak256(""), "!baseURI");
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
        emit SaleInitialized(_msgSender(), _whitelistMerkleRoot, block.timestamp + _publicSaleOffset);
    }

    /// @dev Set Private claiming merkle root (only once)
    /// @param _root Private Merkle Root
    function setPrivateRoot(bytes32 _root) external onlyAdmin {
        require(privateMerkleRoot == bytes32(0), "Merkle root already set");
        privateMerkleRoot = _root;
        emit PrivateMerkleRootSet(_msgSender(), _root);
    }

    /// @dev Set Airdrop merkle root (multiple times)
    /// @param _root Airdrop Merkle Root
    function setAirdropRoot(bytes32 _root) external onlyAdmin {
        require(airdropClaimed < AIRDROP_MAX_CLAIMS, "!airdrop");
        airdropMerkleRoot = _root;
        emit AirdropMerkleRootSet(_msgSender(), ++airdropNonce, _root);
    }

    /// @dev Set new base image URI for collections
    /// @param _uri Base image URI
    function setImageBaseURI(string memory _uri) external onlyAdmin {
        _setURI(_uri);
        emit NewImageUri(_msgSender(), _uri);
    }

    /// @notice Claim private whitelisted tokens
    /// @param _proof Private Merkle Proof
    function privateClaim(bytes32[] memory _proof) external {
        require(MerkleProof.verify(_proof, privateMerkleRoot, keccak256(abi.encodePacked(_msgSender()))), "!root");
        require(!userPrivateClaimed[_msgSender()], "claimed");
        _mint(_msgSender(), uint256(Pioneer.GOLD), PRIVATE_CLAIM_GOLD, bytes(""));
        userPrivateClaimed[_msgSender()] = true;
        emit PrivateClaim(_msgSender());
    }

    /// @notice Purchase whilelisted tokens (maximum amount: WHITELIST_PURCHASE_PER_ADDRESS)
    /// @param _amount Amount to purchase
    /// @param _proof Whitelist Merkle Proof
    function whitelistPurchase(uint256 _amount, bytes32[] memory _proof) external payable {
        require(whitelistMerkleRoot != bytes32(0), "!initialized");
        require(MerkleProof.verify(_proof, whitelistMerkleRoot, keccak256(abi.encodePacked(_msgSender()))), "!root");
        require(purchasedAmount + _amount <= PURCHASABLE_SUPPLY, "!purchase");
        require(
            userWhitelistPurchasedAmount[_msgSender()] + _amount <= WHITELIST_PURCHASE_PER_ADDRESS,
            "Maximum amount purchased"
        );
        _processPurchaseRequest(whitelistTokenUnitPrice, _amount);
        userWhitelistPurchasedAmount[_msgSender()] += _amount;
        purchasedAmount += _amount;
        emit WhitelistPurchase(_msgSender(), _amount);
    }

    /// @notice Purchase Pioneer NFTs randomly from the 3 collections (Bronze, Silver and Gold)
    /// @param _amount Amount to purchase
    function publicPurchase(uint256 _amount) external payable {
        require(publicSaleStarted(), "!start");
        require(purchasedAmount + _amount <= PURCHASABLE_SUPPLY, "!purchase");
        _processPurchaseRequest(publicTokenUnitPrice, _amount);
        purchasedAmount += _amount;
        emit PublicPurchase(_msgSender(), _amount);
    }

    /// @notice Claim airdrop
    /// @param _amount Amount to claim
    /// @param _proof Airdrop Merkle Proof
    function claimAirdrop(uint256 _amount, bytes32[] memory _proof) external {
        require(
            MerkleProof.verify(_proof, airdropMerkleRoot, keccak256(abi.encodePacked(_msgSender(), _amount))),
            "!merkleRoot"
        );
        require(airdropClaimed + _amount <= AIRDROP_MAX_CLAIMS, "!airdrop");
        uint256 airdropNonce_ = airdropNonce;
        require(userAirdropNonce[_msgSender()] < airdropNonce_, "!userNonce");
        _processPurchaseRequest(0, _amount);
        airdropClaimed += _amount;
        userAirdropNonce[_msgSender()] = airdropNonce_;
        emit AirdropClaim(_msgSender(), _amount);
    }

    /// @dev Withdraw all ethers from contract
    /// @param _to Address to send the funds
    function withdraw(address _to) external onlyAdmin {
        uint256 etherBalance = address(this).balance;
        require(etherBalance > 0, "No ethers to withdraw");
        _sendValue(_to, etherBalance);
        emit Withdrawal(_msgSender(), _to, etherBalance);
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
            keccak256(abi.encodePacked(_msgSender(), block.timestamp, _amount, purchasedAmount))
        );

        uint256 chance;
        uint256[3] memory amounts;
        for (uint256 i = 0; i < _amount; i++) {
            chance = magicValue % MAX_CHANCE;
            if (chance < thresholds[Pioneer.BRONZE]) ++amounts[0];
            else if (chance < thresholds[Pioneer.SILVER]) ++amounts[1];
            else ++amounts[2];
            magicValue = uint256(keccak256(abi.encodePacked(magicValue / MAX_CHANCE)));
        }

        for (uint8 i = 0; i < amounts.length; i++) {
            if (amounts[i] == 0) continue;
            _mint(_msgSender(), i, amounts[i], bytes(""));
            emit PioneerClaim(_msgSender(), Pioneer(i), _tokenUnitPrice, amounts[i]);
        }
        uint256 surplus = msg.value - totalPrice;
        if (surplus > 0) _sendValue(_msgSender(), surplus);
    }
}
