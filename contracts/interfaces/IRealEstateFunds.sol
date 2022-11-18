// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IRealEstateFunds {
    function deposit(uint256 _id, uint256 _amount, address _currency) external;
}
