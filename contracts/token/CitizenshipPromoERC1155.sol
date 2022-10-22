// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { Base64 } from "@openzeppelin/contracts/utils/Base64.sol";
import { Strings } from "@openzeppelin/contracts/utils/Strings.sol";
import { RoyalERC1155 } from "./RoyalERC1155.sol";

contract CitizenshipPromoERC1155 is RoyalERC1155 {
    using Strings for uint256;

    enum Citizenship {
        BRONZE,
        SILVER,
        GOLD
    }

    uint256 public constant PURCHASEABLE_SUPPLY = 10550;
    uint256 public constant MAX_CHANCE = 10000;
    uint256 public immutable tokenUnitPrice;

    uint256 public purchasedAmount;

    mapping(Citizenship => uint256) public chances;

    bytes32 public goldMerkleRoot;
    bytes32 public silverMerkleRoot;

    mapping(address => bool) goldClaimed;
    mapping(address => bool) silverClaimed;

    event GoldMerkleRootSet(address indexed _admin, bytes32 _root);
    event SilverMerkleRootSet(address indexed _admin, bytes32 _root);
    event NewImageUri(address indexed _admin, string _uri);

    event Withdrawal(address indexed _admin, address indexed _to, uint256 _amount);

    event CitizenshipClaimed(
        address indexed _by,
        Citizenship indexed _citizenship,
        bool indexed _isPrivilege,
        uint256 _amount
    );

    constructor(
        string memory _imageUri,
        address _admin,
        address _owner,
        uint256 _tokenUnitPrice,
        uint256[3] memory _chances
    ) RoyalERC1155(_imageUri, _admin, _owner) {
        uint256 totalChances;
        for (uint8 i = 0; i < _chances.length; i++) {
            if (i > 0) {
                require(_chances[i - 1] >= _chances[i], "Invalid _chance array");
            }
            chances[Citizenship(i + 1)] = _chances[i];
            totalChances += _chances[i];
        }
        require(totalChances == MAX_CHANCE, "_chances sum should be MAX_CHANCE");
        tokenUnitPrice = _tokenUnitPrice;
        emit NewImageUri(msg.sender, _imageUri);
    }

    function setGoldMerkleRoot(bytes32 _root) external onlyAdmin {
        require(goldMerkleRoot == bytes32(0), "Merkle root already set");
        goldMerkleRoot = _root;
        emit GoldMerkleRootSet(msg.sender, _root);
    }

    function setSilverMerkleRoot(bytes32 _root) external onlyAdmin {
        require(silverMerkleRoot == bytes32(0), "Merkle root already set");
        silverMerkleRoot = _root;
        emit SilverMerkleRootSet(msg.sender, _root);
    }

    function setImageBaseURI(string memory _uri) external onlyAdmin {
        _setURI(_uri);
        emit NewImageUri(msg.sender, _uri);
    }

    function claimGold(bytes32[] memory _proof) external {
        require(MerkleProof.verify(_proof, goldMerkleRoot, keccak256(abi.encodePacked(msg.sender))), "Access Denied");
        require(!goldClaimed[msg.sender], "Already claimed");
        _mint(msg.sender, uint256(Citizenship.GOLD), 1, bytes(""));
        emit CitizenshipClaimed(msg.sender, Citizenship.GOLD, true, 1);
    }

    function claimSilver(bytes32[] memory _proof) external {
        require(MerkleProof.verify(_proof, goldMerkleRoot, keccak256(abi.encodePacked(msg.sender))), "Access Denied");
        require(!goldClaimed[msg.sender], "Already claimed");
        _mint(msg.sender, uint256(Citizenship.GOLD), 1, bytes(""));
        emit CitizenshipClaimed(msg.sender, Citizenship.GOLD, true, 1);
    }

    function purchase(uint256 _amount) external payable {
        uint256 totalPrice = _amount * tokenUnitPrice;
        require(msg.value >= totalPrice, "Not enough ethers");
        require(purchasedAmount + _amount <= PURCHASEABLE_SUPPLY, "_amount is to big");
        uint256 magicValue = uint256(
            keccak256(abi.encodePacked(msg.sender, block.timestamp, _amount, purchasedAmount))
        );

        uint256 chance;
        uint256[3] memory amounts;
        for (uint256 i = 0; i < _amount; i++) {
            chance = magicValue % MAX_CHANCE;
            if (chance < chances[Citizenship.BRONZE]) amounts[0]++;
            else if (chance < chances[Citizenship.SILVER]) amounts[1]++;
            else amounts[2]++;
            magicValue = uint256(keccak256(abi.encodePacked(magicValue / MAX_CHANCE)));
        }

        for (uint8 i = 0; i < amounts.length; i++) {
            if (amounts[i] == 0) continue;
            _mint(msg.sender, i + 1, amounts[i], bytes(""));
            emit CitizenshipClaimed(msg.sender, Citizenship(i + 1), false, amounts[i]);
        }
        uint256 surplus = msg.value - totalPrice;
        if (surplus > 0) _sendValue(msg.sender, surplus);
    }

    function withdraw(address _to) external onlyAdmin {
        uint256 etherBalance = address(this).balance;
        require(etherBalance > 0, "No ethers to withdraw");
        _sendValue(msg.sender, etherBalance);
        emit Withdrawal(msg.sender, _to, etherBalance);
    }

    function uri(uint256 _id) public view override returns (string memory) {
        return string(abi.encodePacked("data:application/json;base64,", Base64.encode(bytes(tokenMetadata(_id)))));
    }

    function tokenMetadata(uint256 _id) public view returns (string memory) {
        return
            string(
                abi.encodePacked(
                    "{ 'name': ",
                    tokenName(_id),
                    ", 'description': ",
                    tokenDescription(_id),
                    ", 'image: '",
                    imageURI(_id)
                )
            );
    }

    function tokenName(uint256 _id) public pure returns (string memory) {
        require(_id >= uint256(Citizenship.BRONZE) && _id <= uint256(Citizenship.GOLD), "Invalid token ID");
        if (_id == uint256(Citizenship.BRONZE)) return "Bronze Citizenship";
        if (_id == uint256(Citizenship.GOLD)) return "Silver Citizenship";
        return "Gold Citizenship";
    }

    function tokenDescription(uint256 _id) public pure returns (string memory) {
        require(_id >= uint256(Citizenship.BRONZE) && _id <= uint256(Citizenship.GOLD), "Invalid token ID");
        if (_id == uint256(Citizenship.BRONZE)) return "";
        if (_id == uint256(Citizenship.GOLD)) return "";
        return "";
    }

    function imageURI(uint256 _id) public view returns (string memory) {
        return string(abi.encodePacked(super.uri(uint256(0)), _id.toString()));
    }

    function _sendValue(address _to, uint256 _amount) internal {
        (bool success, ) = _to.call{ value: _amount }("");
        require(success, "Failed sending ethers");
    }
}
