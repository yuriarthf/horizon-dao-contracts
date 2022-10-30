// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IVoteEscrow {
    function lock(uint256 _amount, uint256 _period) external;
}
