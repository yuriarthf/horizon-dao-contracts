// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface IRealEstateERC1155 {
    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function nextRealEstateId() external view returns (uint256);

    function setMinter(address _minter) external;

    function setBurner(address _burner) external;

    function mint(uint256 _id, address _to, uint256 _amount) external;

    function burn(uint256 _id, uint256 _amount) external;
}
