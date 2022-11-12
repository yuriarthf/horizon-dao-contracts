// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { ERC20Permit } from "../token/ERC20Permit.sol";

contract NonERC165ERC20PermitMock is ERC20Permit {
    constructor(string memory _name, string memory _symbol) ERC20Permit(_name, _symbol) {}

    function freeMint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4) external pure virtual override returns (bool) {
        return false;
    }
}
