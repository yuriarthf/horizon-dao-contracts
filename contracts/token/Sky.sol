// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title SkyERC20
/// @notice HorizonDAO Governance token
/// @author Yuri Fernandes
contract SkyERC20 is ERC20 {
    /// @dev Maximum supply of 100M tokens (with 18 decimal points)
    uint256 public constant MAX_SUPPLY = 100_000_000 * 1e18;

    /// @dev Address of the admin: Can set new admin, burner and minter addresses
    address public admin;

    /// @dev Address of the burner: Can execute burn function
    address public burner;

    /// @dev Address of the minter: Can execute mint function
    address public minter; // TODO: Will it be only one minter?

    /// @dev Checks if msg.sender is the admin
    modifier onlyAdmin() {
        require(msg.sender == admin, "!admin");
        _;
    }

    /// @dev Emitted when a new admin is set
    event NewAdmin(address indexed _admin);

    /// @dev Emitted when a new burner is set
    event NewBurner(address indexed _burner);

    /// @dev Emitted when a new minter is set
    event NewMinter(address indexed _minter);

    /// @dev Initialize SkyERC20 contract
    /// @param _name Token name
    /// @param _symbol Token Symbol
    constructor(
        string memory _name,
        string memory _symbol,
        address _admin
    ) ERC20(_name, _symbol) {
        // set contract admin
        admin = _admin;

        emit NewAdmin(_admin);
    }

    /// @dev Set new admin role
    /// @param _admin New admin address
    function setAdmin(address _admin) external onlyAdmin {
        admin = _admin;
        emit NewAdmin(_admin);
    }

    /// @dev Set new burner role
    /// @param _burner New burner address
    function setBurner(address _burner) external onlyAdmin {
        burner = _burner;
        emit NewBurner(_burner);
    }

    /// @dev Set new minter role
    /// @param _minter New minter address
    function setMinter(address _minter) external onlyAdmin {
        minter = _minter;
        emit NewMinter(_minter);
    }

    /// @dev Mints an amount of tokens to an arbitrary account
    /// @dev MINTER_ROLE is required to execute this function
    /// @param account The account to mint the tokens to
    /// @param amount The amount of tokens to mint
    function mint(address account, uint256 amount) external {
        require(msg.sender == minter, "!minter");
        // TODO: Add some logic to determine the current max supply
        _mint(account, amount);
    }

    /// @dev Burns an amount of tokens owned by the msg.sender
    /// @dev BURNER_ROLE is required to execute this function
    /// @dev This function is designed so that users can migrate it's tokens
    /// to a new ERC20 contract. This contract should take the tokens on it's custody
    /// burn the legacy tokens and mint new ones for the msg.sender
    function burn(uint256 amount) external {
        require(msg.sender == burner, "!burner");
        _burn(msg.sender, amount);
    }
}
