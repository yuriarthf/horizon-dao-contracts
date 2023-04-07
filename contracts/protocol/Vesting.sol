// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { ERC721 } from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import { ERC721URIStorage } from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";
import { IVoteEscrow } from "../interfaces/IVoteEscrow.sol";

/// @title Vesting
/// @dev Used to vest underlying ERC20 for various addresses
/// @author HorizonDAO (Yuri Fernandes)
contract Vesting is ERC721URIStorage, Ownable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    /// @dev Multiplier used during division operations to decrease rounding errors
    uint256 public constant BASE_MULTIPLIER = 1e18;

    /// @dev Minimum vesting period
    uint256 public constant MIN_VESTING_PERIOD = 365 days; // 1 year

    /// @dev Maximum vesting period
    uint256 public constant MAX_VESTING_PERIOD = 4 * 365 days; // 4 years

    /// @dev Minimum lock period after claiming vested tokens (if lockVested is false, locking is not required)
    uint256 public constant LOCK_VESTED_MIN_PERIOD = 365 days; // 1 year

    /// @dev Maximum lock period after claiming vested tokens
    uint256 public constant LOCK_VESTED_MAX_PERIOD = 4 * 365 days; // 4 years

    /// @dev Position structure containing required data:
    ///     - owner: Who'll have control over vested tokens
    ///     - amount: Amount of tokens to be vested in the position
    ///     - amountPaid: Amount of vested tokens claimed
    ///     - vestingStart: When tokens start to vest
    ///     - vestingEnd: When tokens vest completely
    ///     - lockVested: Whether to enforce token locking after vested
    struct Position {
        address owner;
        uint256 amount;
        uint256 amountPaid;
        uint256 vestingStart;
        uint256 vestingEnd;
        bool lockVested;
    }

    /// @dev Underlying vested token address
    address public immutable underlying;

    /// @dev VoteEscrow address, where tokens will be locked
    address public voteEscrow;

    /// @dev Amount of tokens been vested
    uint256 public totalVesting;

    /// @dev ID of the next vested position ID
    Counters.Counter private _currentPositionId;

    /// @dev How many positions vested (all tokens claimed)
    Counters.Counter private _vestedPositions;

    /// @dev Array containing all vesting positions
    Position[] public positions;

    /// @dev mapping (user => vestingPostions)
    /// @dev Contains the user vesting positions' indexes
    mapping(address => uint256[]) public userPositionIndexes;

    /// @dev Emitted when a new Vote Escrow contract is set
    event VoteEscrowSet(address indexed _admin, address _voteEscrow);

    /// @dev Emitted when a new vested position is created
    event PositionCreated(
        address indexed _admin,
        address indexed _to,
        uint256 indexed _positionId,
        uint256 _amount,
        uint256 _vestingStart,
        uint256 _vestingEnd,
        bool _lockVested
    );

    /// @dev Emitted when an amount of vested tokens is claimed
    event AmountClaimed(address indexed _by, address indexed _recipient, uint256 _amount, uint256 _voteLockPeriod);

    /// @dev Initialize Vesting contract
    /// @param _underlying Address of the underlying vesting asset
    constructor(address _underlying) ERC721("Horizon Bonds", "HZB") {
        require(
            IERC165(_underlying).supportsInterface(type(IERC20).interfaceId),
            "Underlying should be IERC20 compatible"
        );
        underlying = _underlying;
    }

    /// @dev Set a vote escrow contract
    /// @param _voteEscrow Address of the vote escrow contract
    function setVoteEscrow(address _voteEscrow) external onlyOwner {
        voteEscrow = _voteEscrow;
        emit VoteEscrowSet(_msgSender(), _voteEscrow);
    }

    /// @dev Create a new vesting position
    /// @param _to The address of the vesting position owner
    /// @param _amount Amount of underlying to be vested
    /// @param _cliffPeriod Period of time that tokens won't vest
    /// @param _vestingDuration Amount of time tokens will vest
    /// @param _lockVested Whether vested underlying locking will be enforced
    function createPosition(
        address _to,
        uint256 _amount,
        uint256 _cliffPeriod,
        uint256 _vestingDuration,
        bool _lockVested
    ) external onlyOwner {
        require(_to != address(0), "Invalid owner");
        require(
            _vestingDuration >= MIN_VESTING_PERIOD && _vestingDuration <= MAX_VESTING_PERIOD,
            "Invalid vesting duration"
        );
        require(usableSupply() >= _amount, "Insufficient underlying");
        uint256 vestingStart = block.timestamp + _cliffPeriod;
        uint256 vestingEnd = vestingStart + _vestingDuration;
        positions.push(
            Position({
                owner: _to,
                amount: _amount,
                amountPaid: 0,
                vestingStart: vestingStart,
                vestingEnd: vestingEnd,
                lockVested: _lockVested
            })
        );
        uint256 currentPositionId = _currentPositionId.current();
        _safeMint(_to, currentPositionId);
        userPositionIndexes[_to].push(currentPositionId);
        _currentPositionId.increment();
        totalVesting += _amount;

        emit PositionCreated(_msgSender(), _to, currentPositionId, _amount, vestingStart, vestingEnd, _lockVested);
    }

    /// @notice Claim vested underlying
    /// @param _positionId ID of the position to claim vested tokens
    /// @param _recipient Recipient of the vested tokens
    /// @param _lockVestedPeriod Amount of time to lock vested tokens (mandatory if lockVested is true)
    function claim(uint256 _positionId, address _recipient, uint256 _lockVestedPeriod) external {
        Position memory userPosition = positions[_positionId];
        require(userPosition.owner == _msgSender(), "Invalid position");
        require(userPosition.vestingStart >= block.timestamp, "Vesting hasn't started");
        require(_recipient != address(0), "Invalid recipient");
        (uint256 amountDue_, uint256 prevAmountPaid_) = _amountDuePaid(userPosition);
        if (amountDue_ == 0) return;
        if (userPosition.lockVested || _lockVestedPeriod > 0) {
            require(voteEscrow != address(0), "No vote escrow");
            require(
                _lockVestedPeriod >= MIN_VESTING_PERIOD && _lockVestedPeriod <= MAX_VESTING_PERIOD,
                "Invalid lock time"
            );
            IERC20(underlying).safeApprove(voteEscrow, amountDue_);
            IVoteEscrow(voteEscrow).lock(_recipient, amountDue_, _lockVestedPeriod);
        } else {
            IERC20(underlying).safeTransfer(_recipient, amountDue_);
        }
        positions[_positionId].amountPaid += amountDue_;
        totalVesting -= amountDue_;

        if (prevAmountPaid_ + amountDue_ == 0) _vestedPositions.increment();

        emit AmountClaimed(_msgSender(), _recipient, amountDue_, _lockVestedPeriod);
    }

    /// @notice Size of the positions array (how many vested positions exist)
    function vestedPositions() external view returns (uint256) {
        return _currentPositionId.current();
    }

    /// @notice How many position still contain vesting tokens
    function activeVestedPositions() external view returns (uint256) {
        return _currentPositionId.current() - _vestedPositions.current();
    }

    /// @notice Amount of underlying tokens Vesting contract owns
    function totalSupply() public view returns (uint256) {
        return IERC20(underlying).balanceOf(address(this));
    }

    /// @notice Amount of tokens available to be vested
    function usableSupply() public view returns (uint256) {
        return totalSupply() - totalVesting;
    }

    /// @notice Amount of vested tokens for a specific position
    /// @param _positionId ID of the position
    /// @return Claimable amount
    function amountDue(uint256 _positionId) public view returns (uint256) {
        Position memory userPosition = positions[_positionId];
        (uint256 amountDue_, ) = _amountDuePaid(userPosition);
        return amountDue_;
    }

    /// @notice Amount of vested tokens paid for a specific position
    /// @param _positionId ID of the position
    /// @return Paid amount
    function amountPaid(uint256 _positionId) public view returns (uint256) {
        Position memory userPosition = positions[_positionId];
        (, uint256 amountPaid_) = _amountDuePaid(userPosition);
        return amountPaid_;
    }

    /// @notice Total amount of vested underlying for an user
    /// @param _account User address
    /// @return Total vested amount
    function userTotalAmountDue(address _account) external view returns (uint256) {
        uint256[] memory userPositionIndexes_ = userPositionIndexes[_account];
        uint256 totalAmountDue;
        uint256 amountDue_;
        for (uint256 i = 0; i < userPositionIndexes_.length; i++) {
            (amountDue_, ) = _amountDuePaid(positions[userPositionIndexes_[i]]);
            totalAmountDue += amountDue_;
        }
        return totalAmountDue;
    }

    /// @notice Returns the position indexes for a given user (comma-separated)
    /// @param _account User address
    /// @return Comma-separated user positions' indexes
    function getUserPositionIndexes(address _account) external view returns (string memory) {
        uint256[] memory userPositionIndexes_ = userPositionIndexes[_account];
        bytes memory positionIndexes = "";
        for (uint256 i = 0; i < userPositionIndexes_.length; i++) {
            positionIndexes = abi.encodePacked(positionIndexes);
            if (i != userPositionIndexes_.length) positionIndexes = abi.encodePacked(positionIndexes, ", ");
        }
        return string(positionIndexes);
    }

    /// @dev Calculates the amount of vested tokens due for a given position and the amount already paid
    /// @param _position Position instance
    /// @return amountDue_ Claimable amount
    /// @return amountPaid_ Paid amount
    function _amountDuePaid(Position memory _position) internal view returns (uint256 amountDue_, uint256 amountPaid_) {
        amountPaid_ = _position.amountPaid;
        amountDue_ =
            ((((
                block.timestamp < _position.vestingEnd ? block.timestamp : _position.vestingEnd - _position.vestingStart
            ) * _position.amount) * BASE_MULTIPLIER) / (_position.vestingEnd - _position.vestingStart)) /
            BASE_MULTIPLIER -
            amountPaid_;
    }

    /// @inheritdoc ERC721
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 firstTokenId,
        uint256 batchSize
    ) internal virtual override {
        require(from == address(0), "Err: token transfer is BLOCKED");
        super._beforeTokenTransfer(from, to, firstTokenId, batchSize);
    }
}
