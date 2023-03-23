// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC20PermitMock } from "./ERC20PermitMock.sol";

contract USDTMock is ERC20PermitMock {
    address public authority;

    constructor(address _authority) ERC20PermitMock("USDT Mock", "USDT") {
        authority = _authority;
    }

    function changeAuthority(address _authority) external {
        require(msg.sender == authority, "!authority");
        authority = _authority;
    }

    function freeMint(address _to, uint256 _amount) public override {
        require(msg.sender == authority, "!authority");
        super.freeMint(_to, _amount);
    }
}
