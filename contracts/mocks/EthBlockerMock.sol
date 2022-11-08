// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract EthBlockerMock {
    receive() external payable {
        revert();
    }
}
