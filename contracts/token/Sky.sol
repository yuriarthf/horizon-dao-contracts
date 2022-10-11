// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title SkyERC20
/// @notice HorizonDAO Governance token
/// @author HorizonDAO (Yuri Fernandes)
contract SkyERC20 is ERC20 {
    /// @dev Maximum supply of 100M tokens (with 18 decimal points)
    uint256 public constant MAX_SUPPLY = 200_000_000 * 1e18;

    /// @dev Address of the admin: Can set new admin, burner and minter addresses
    address public admin;

    /// @dev Address of the burner: Can execute burn function
    address public burner;

    /// @dev Address of the minter: Can execute mint function
    address public minter; // TODO: Will it be only one minter?

    /// @dev Current epoch start time
    uint64 public currentEpochStartTime;

    /// @dev Total number of epochs
    uint256 public immutable numberOfEpochs;

    /// @dev Current epoch
    uint256 public currentEpoch;

    /// @dev Values to increment the availableSupply at the end of an epoch
    uint256[] public rampValues;

    /// @dev Durations for the epochs, should be of size n-1 (n is the number of epochs)
    /// @dev The last epoch duration would be infinite
    uint256[] public epochDurations;

    /// @dev Available supply to be minted
    uint256 private availableSupply;

    /// @dev Checks if msg.sender is the admin
    modifier onlyAdmin() {
        require(msg.sender == admin, "!admin");
        _;
    }

    /// @dev Update available supply
    modifier updateAvailableSupply() {
        if (
            currentEpoch == 0 ||
            (currentEpoch != numberOfEpochs &&
                now64() >= currentEpochStartTime + epochDurations[epochDurations[currentEpoch]])
        ) {
            (availableSupply, currentEpoch, currentEpochStartTime) = getUpdatedEpochMetadata();
        }
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
        address _admin,
        uint256 _numberOfEpochs,
        uint256[] memory _epochDurations,
        uint64 _initialEpochStart,
        uint256[] memory _rampValues
    ) ERC20(_name, _symbol) {
        require(_numberOfEpochs >= 1, "Should have at least 1 epoch");
        require(_rampValues.length == _numberOfEpochs, "Number of ramps should be equal to epochs");
        require(_epochDurations.length == _numberOfEpochs - 1, "Epoch durations should be provided for n-1 epochs");
        uint256 totalReleasedSupply;
        for (uint256 i = 0; i < _rampValues.length; i++) {
            totalReleasedSupply += _rampValues[i];
            rampValues.push(_rampValues[i]);
            if (i != _rampValues.length) epochDurations.push(_epochDurations[i]);
        }
        require(totalReleasedSupply == MAX_SUPPLY, "Sum of ramps should be equal to MAX_SUPPLY");
        // set availableSupply as the first rampValue
        // and numberOfEpochs
        currentEpochStartTime = _initialEpochStart;
        numberOfEpochs = _numberOfEpochs;

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
    function mint(address account, uint256 amount) external updateAvailableSupply {
        require(msg.sender == minter, "!minter");
        require(amount <= availableSupply - totalSupply(), "Not enough tokens to be minted");
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

    function now64() public view returns (uint64) {
        return uint64(block.timestamp);
    }

    function getAvailableSupply() public view returns (uint256) {
        if (currentEpoch == numberOfEpochs) return MAX_SUPPLY;
        if (now64() < currentEpochStartTime) return 0;
        if (now64() < currentEpochStartTime + epochDurations[epochDurations[currentEpoch]]) {
            return availableSupply;
        }
        (uint256 availableSupply_, , ) = getUpdatedEpochMetadata();
        return availableSupply_;
    }

    function getAvailableTokensToMint() public view returns (uint256) {
        return getAvailableSupply() - totalSupply();
    }

    function getUpdatedEpochMetadata()
        internal
        view
        returns (
            uint256 _availableSupply,
            uint256 _currentEpoch,
            uint64 _currentEpochStartTime
        )
    {
        _availableSupply = availableSupply;
        _currentEpoch = currentEpoch;
        _currentEpochStartTime = currentEpochStartTime;
        while (_currentEpochStartTime + epochDurations[_currentEpoch] <= now64()) {
            _availableSupply += rampValues[++_currentEpoch];
            _currentEpochStartTime += uint64(epochDurations[_currentEpoch]);
            if (_currentEpoch == numberOfEpochs) break;
        }
    }
}
