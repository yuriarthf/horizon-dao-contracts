// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC20Permit } from "../token/ERC20Permit.sol";

contract ERC20PermitMock is ERC20Permit {
    constructor(string memory _name, string memory _symbol) ERC20Permit(_name, _symbol) {}

    function freeMint(address _to, uint256 _amount) public virtual {
        _mint(_to, _amount);
    }
}
