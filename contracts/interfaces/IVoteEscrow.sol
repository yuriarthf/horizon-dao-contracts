// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IVoteEscrow {
    function lock(address _to, uint256 _amount, uint256 _period) external;
}
