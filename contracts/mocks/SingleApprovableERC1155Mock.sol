// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC1155 } from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import { SingleApprovableERC1155 } from "../token/SingleApprovableERC1155.sol";

contract SingleApprovableERC1155Mock is SingleApprovableERC1155 {
    address msgSenderMock;
    bool mockMsgSender;

    constructor(string memory _uri) ERC1155(_uri) {}

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
}
