// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title SkyERC20
/// @notice HorizonDAO Governance token
/// @author HorizonDAO (Yuri Fernandes)
contract SkyERC20 is ERC20 {
    /// @dev Maximum supply of 100M tokens (with 18 decimal points)
    uint256 public constant MAX_SUPPLY = 100_000_000 * 1e18;

    /// @dev Address of the admin: Can set new admin, burner and minter addresses
    address public admin;

    /// @dev Address of the burner: Can execute burn function
    address public burner;

    /// @dev Address of the minter: Can execute mint function
    address public minter; // TODO: Will it be only one minter?

    /// @dev When the first epoch starts
    uint64 public firstEpochStartTime;

    /// @dev Durations for the epochs, should be of size n-1 (n is the number of epochs)
    /// @dev The last epoch duration would be infinite
    uint64[] public epochDurations;

    /// @dev Total number of epochs
    uint8 public immutable numberOfEpochs;

    /// @dev Values to increment the availableSupply at the end of an epoch
    uint256[] public rampValues;

    /// @dev Keeps track of minted supply
    uint256 public mintedSupply;

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
    /// @param _firstEpochStartTime When the first epoch starts
    /// @param _epochDurations The duration of each epoch (last epoch duration is infinite)
    /// @param _rampValues How much to increase the availableSupply at each epoch
    constructor(
        address _admin,
        uint8 _numberOfEpochs,
        uint64 _firstEpochStartTime,
        uint64[] memory _epochDurations,
        uint256[] memory _rampValues
    ) ERC20("HorizonDAO Token", "SKY") {
        require(_numberOfEpochs >= 1, "_numberOfEpochs == 0");
        require(_rampValues.length == _numberOfEpochs, "_rampValues.length != _numberOfEpochs");
        require(_epochDurations.length == _numberOfEpochs - 1, "_epochDurations.length != _numberOfEpochs-1");
        uint256 totalReleasedSupply;
        for (uint256 i = 0; i < _rampValues.length; i++) {
            totalReleasedSupply += _rampValues[i];
            rampValues.push(_rampValues[i]);
            if (i != _rampValues.length - 1) epochDurations.push(_epochDurations[i]);
        }
        require(totalReleasedSupply == MAX_SUPPLY, "totalReleasedSupply != MAX_SUPPLY");
        // set the first epoch start time
        firstEpochStartTime = _firstEpochStartTime;

        // set the total number of epochs
        numberOfEpochs = _numberOfEpochs;

        // set contract admin
        admin = _admin;
        emit NewAdmin(_admin);
    }

    /// @notice get current epoch
    function currentEpoch() external view returns (uint8 _currentEpoch) {
        (_currentEpoch, , ) = _getEpochInfo();
    }

    /// @notice get current epoch start time
    function currentEpochStartTime() external view returns (uint64 _currentEpochStartTime) {
        (, _currentEpochStartTime, ) = _getEpochInfo();
    }

    /// @notice get available supply
    function availableSupply() public view returns (uint256 _availableSupply) {
        (, , _availableSupply) = _getEpochInfo();
    }

    /// @notice Get the amount of mintable tokens at the moment
    function mintableSupply() public view returns (uint256) {
        return availableSupply() - mintedSupply;
    }

    /// @notice Get the current timestamp converted to uint64
    function now64() public view returns (uint64) {
        return uint64(block.timestamp);
    }

    /// @notice Has supply releasing epochs started? (first epoch)
    function supplyReleaseStarted() external view returns (bool) {
        return now64() >= firstEpochStartTime;
    }

    /// @dev Set new admin role
    /// @param _admin New admin address
    function setAdmin(address _admin) external onlyAdmin {
        require(admin != _admin, "admin == _admin");
        admin = _admin;
        emit NewAdmin(_admin);
    }

    /// @dev Set new burner role
    /// @param _burner New burner address
    function setBurner(address _burner) external onlyAdmin {
        require(burner != _burner, "burner == _burner");
        burner = _burner;
        emit NewBurner(_burner);
    }

    /// @dev Set new minter role
    /// @param _minter New minter address
    function setMinter(address _minter) external onlyAdmin {
        require(minter != _minter, "minter == _minter");
        minter = _minter;
        emit NewMinter(_minter);
    }

    /// @dev Mints an amount of tokens to an arbitrary account
    /// @dev MINTER_ROLE is required to execute this function
    /// @param account The account to mint the tokens to
    /// @param amount The amount of tokens to mint
    function mint(address account, uint256 amount) external {
        require(msg.sender == minter, "!minter");
        (uint8 _currentEpoch, , uint256 _availableSupply) = _getEpochInfo();
        uint256 _mintableSupply = _availableSupply - mintedSupply;
        require(amount <= _mintableSupply, "amount > mintableSupply");
        _mint(account, amount);
        mintedSupply += amount;
        emit SupplyMinted(msg.sender, account, _currentEpoch, amount, _mintableSupply);
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

    /// @dev Get updated epoch info
    /// @return _currentEpoch The current epoch number
    /// @return _currentEpochStartTime The current epoch start time
    /// @return _availableSupply Current available supply (unlocked)
    function _getEpochInfo()
        internal
        view
        returns (
            uint8 _currentEpoch,
            uint64 _currentEpochStartTime,
            uint256 _availableSupply
        )
    {
        // store in memory to save gas
        _currentEpochStartTime = firstEpochStartTime;

        // check if epochs have started
        if (now64() < _currentEpochStartTime) return (_currentEpoch, uint64(0), _availableSupply);

        // store in memory to save gas
        uint8 _numberOfEpochs = numberOfEpochs;
        uint64[] memory _epochDurations = epochDurations;
        uint256[] memory _rampValues = rampValues;

        // update epoch info until it the current epoch reaches the maximum number
        // of epochs or current time is less than the current epoch start time
        // plus the current epoch duration
        _currentEpoch = 1;
        _availableSupply += _rampValues[_currentEpoch - 1];
        while (
            _currentEpoch < _numberOfEpochs && now64() >= _currentEpochStartTime + _epochDurations[_currentEpoch - 1]
        ) {
            _currentEpochStartTime += _epochDurations[_currentEpoch - 1];
            _availableSupply += _rampValues[_currentEpoch];
            ++_currentEpoch;
        }
    }
}
