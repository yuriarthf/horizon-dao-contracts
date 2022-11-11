// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC20Permit } from "./ERC20Permit.sol";

/// @title Sky Token
/// @author Yuri Fernandes (HorizonDAO)
/// @notice HorizonDAO Governance token
contract SkyERC20 is ERC20Permit {
    /// @dev Maximum supply of 100M tokens (with 18 decimal points)
    uint256 public constant MAX_SUPPLY = 100_000_000 * 1e18;

    /// @dev Address of the admin: Can set new admin, burner and minter addresses
    address public admin;

    /// @dev Address of the minter: Can execute mint function
    address public minter;

    /// @dev Checks if msg.sender is the admin
    modifier onlyAdmin() {
        require(_msgSender() == admin, "!admin");
        _;
    }

    /// @dev Emitted when a new admin is set
    event SetAdmin(address indexed _by, address indexed _admin);

    /// @dev Emitted when a new minter is set
    event SetMinter(address indexed _by, address indexed _minter);

    /// @dev Emitted when additional supply is minted
    event Mint(address indexed _minter, address indexed _receiver, uint256 _amount);

    /// @dev Initialize SkyERC20 contract
    /// @param _admin Address of the admin of the contract
    constructor(address _admin, uint256 _initialSupply, address _initialHolder) ERC20Permit("HorizonDAO Token", "SKY") {
        require(_initialSupply <= MAX_SUPPLY, "MAX_SUPPLY");

        // mint initial supply
        _mint(_initialHolder, _initialSupply);
        emit Mint(_msgSender(), _initialHolder, _initialSupply);

        // set contract admin
        admin = _admin;
        emit SetAdmin(_msgSender(), _admin);
    }

    /// @dev Set new admin role
    /// @param _admin New admin address
    function setAdmin(address _admin) external onlyAdmin {
        require(admin != _admin, "Same admin");
        admin = _admin;
        emit SetAdmin(_msgSender(), _admin);
    }

    /// @dev Set new minter role
    /// @param _minter New minter address
    function setMinter(address _minter) external onlyAdmin {
        require(minter != _minter, "Same minter");
        minter = _minter;
        emit SetMinter(_msgSender(), _minter);
    }

    /// @dev Mints an amount of tokens to an arbitrary account
    /// @dev MINTER_ROLE is required to execute this function
    /// @param _to Account to mint the tokens to
    /// @param _amount The amount of tokens to mint
    function mint(address _to, uint256 _amount) external {
        require(_msgSender() == minter, "!minter");
        require(totalSupply() + _amount <= MAX_SUPPLY, "MAX_SUPPLY");
        _mint(_to, _amount);
        emit Mint(_msgSender(), _to, _amount);
    }

    /// @notice Returns how many tokens are available for minting
    function mintableSupply() external view returns (uint256) {
        return MAX_SUPPLY - totalSupply();
    }
}
