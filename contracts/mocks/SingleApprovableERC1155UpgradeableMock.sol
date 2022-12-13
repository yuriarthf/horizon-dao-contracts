// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { SingleApprovableERC1155Upgradeable } from "../token/SingleApprovableERC1155Upgradeable.sol";

contract SingleApprovableERC1155UpgradeableMock is SingleApprovableERC1155Upgradeable {
    address private msgSenderMock;
    bool private mockMsgSender;

    function initialize(string memory _uri, address _admin) external initializer {
        __SingleApprovableERC1155_init(_uri, _admin);
    }

    function initChained(string memory _uri, address _admin) external {
        __SingleApprovableERC1155_init(_uri, _admin);
    }

    function initUnchained(address _admin) external {
        __SingleApprovableERC1155_init_unchained(_admin);
    }

    function mint(address _to, uint256 _id, uint256 _amount, bytes memory _data) public {
        _mint(_to, _id, _amount, _data);
    }

    function _msgSender() internal view override returns (address) {
        return mockMsgSender ? msgSenderMock : msg.sender;
    }

    function toggleMsgSenderMock(bool _mock) external {
        mockMsgSender = _mock;
    }

    function setMsgSenderMock(address _mockedAddress) external {
        msgSenderMock = _mockedAddress;
    }

    function setURI(uint256 _tokenId, string memory _tokenURI) external virtual {
        _setURI(_tokenId, _tokenURI);
    }

    function setBaseURI(string memory _baseURI) external virtual {
        _setBaseURI(_baseURI);
    }
}
