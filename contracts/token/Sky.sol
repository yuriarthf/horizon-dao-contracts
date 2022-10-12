// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC20WithSupply } from "boring-solidity/contracts/ERC20.sol";

/// @title SkyERC20
/// @notice HorizonDAO Governance token
/// @author HorizonDAO (Yuri Fernandes)
contract SkyERC20 is ERC20WithSupply {
    /// @dev Tokens' name
    string public constant name = "Horizon Sky";

    /// @dev Tokens' symbol
    string public constant symbol = "SKY";

    /// @dev Maximum supply of 200M tokens (with 18 decimal points)
    uint256 public constant MAX_SUPPLY = 200_000_000 * 1e18;

    /// @dev Address of the admin: Can set new admin, burner and minter addresses
    address public admin;

    /// @dev Address of the burner: Can execute burn function
    address public burner;

    /// @dev Address of the minter: Can execute mint function
    address public minter; // TODO: Will it be only one minter?

    /// @dev Current epoch start time
    uint64 public currentEpochStartTime;

    /// @dev Durations for the epochs, should be of size n-1 (n is the number of epochs)
    /// @dev The last epoch duration would be infinite
    uint64[] public epochDurations;

    /// @dev Total number of epochs
    uint8 public immutable numberOfEpochs;

    /// @dev Current epoch
    uint8 public currentEpoch;

    /// @dev Values to increment the availableSupply at the end of an epoch
    uint256[] public rampValues;

    /// @dev Available supply to be minted
    uint256 private availableSupply;

    /// @dev Checks if msg.sender is the admin
    modifier onlyAdmin() {
        require(msg.sender == admin, "!admin");
        _;
    }

    /// @dev Update epoch metadata
    modifier updateEpochMetadata() {
        if (
            (currentEpoch == 0 && now64() >= currentEpochStartTime) ||
            (currentEpoch != numberOfEpochs &&
                now64() >= currentEpochStartTime + epochDurations[epochDurations[currentEpoch]])
        ) {
            (availableSupply, currentEpoch, currentEpochStartTime) = _getUpdatedEpochMetadata();
        }
        _;
    }

    /// @dev Emitted when a new admin is set
    event NewAdmin(address indexed _admin);

    /// @dev Emitted when a new burner is set
    event NewBurner(address indexed _burner);

    /// @dev Emitted when a new minter is set
    event NewMinter(address indexed _minter);

    /// @dev Emitted when additional supply is minted
    event SupplyMinted(
        address indexed _minter,
        address indexed _receiver,
        uint8 indexed _epoch,
        uint256 _amount,
        uint256 _mintableSupply
    );

    /// @dev Initialize SkyERC20 contract
    /// @param _admin Address of the admin of the contract
    /// @param _numberOfEpochs Number of supply release epochs
    /// @param _initialEpochStart When the first epoch starts
    /// @param _epochDurations The duration of each epoch (last epoch duration is infinite)
    /// @param _rampValues How much to increase the availableSupply at each epoch
    constructor(
        address _admin,
        uint8 _numberOfEpochs,
        uint64 _initialEpochStart,
        uint64[] memory _epochDurations,
        uint256[] memory _rampValues
    ) {
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
        // set the first epoch start time
        currentEpochStartTime = _initialEpochStart;

        // set the total number of epochs
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
    function mint(address account, uint256 amount) external updateEpochMetadata {
        require(msg.sender == minter, "!minter");
        require(amount <= availableSupply - totalSupply, "Not enough tokens to be minted");
        _mint(account, amount);
        emit SupplyMinted(msg.sender, account, currentEpoch, amount, getMintableSupply());
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

    /// @notice Get the current timestamp converted to uint64
    function now64() public view returns (uint64) {
        return uint64(block.timestamp);
    }

    /// @notice Get the unlocked supply corresponding to the current epochss
    function getUnlockedSupply() public view returns (uint256) {
        if (currentEpoch == numberOfEpochs) return MAX_SUPPLY;
        if (now64() < currentEpochStartTime) return 0;
        if (now64() < currentEpochStartTime + epochDurations[epochDurations[currentEpoch]]) {
            return availableSupply;
        }
        (uint256 availableSupply_, , ) = getUpdatedEpochMetadata();
        return availableSupply_;
    }

    /// @notice Get the amount of mintable tokens at the moment
    function getMintableSupply() public view returns (uint256) {
        return getUnlockedSupply() - totalSupply;
    }

    /// @dev Get the updated epoch metadata
    /// @return _availableSupply The current availableSupply
    /// @return _currentEpoch The current epoch
    /// @return _currentEpochStartTime The timestamp of when the
    /// current epoch started
    function _getUpdatedEpochMetadata()
        internal
        view
        returns (
            uint256 _availableSupply,
            uint8 _currentEpoch,
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
