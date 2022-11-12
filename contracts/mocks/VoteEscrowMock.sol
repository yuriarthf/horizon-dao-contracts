// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { IVoteEscrow } from "../interfaces/IVoteEscrow.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract VoteEscrowMock is IVoteEscrow {
    using SafeERC20 for IERC20;

    address public immutable underlying;

    constructor(address _underlying) {
        underlying = _underlying;
    }

    function lock(address, uint256 _amount, uint256) external {
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), _amount);
    }
}
