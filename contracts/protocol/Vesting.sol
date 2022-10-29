// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";

contract Vesting is Ownable {
    using SafeERC20 for IERC20;
    using Counters for Counters.Counter;

    uint256 public constant BASE_MULTIPLIER = 1e8; // Used to mitigate rounding errors
    uint256 public constant MIN_VESTING_PERIOD = 365 days; // 1 year
    uint256 public constant MAX_VESTING_PERIOD = 4 * 365 days; // 4 years
    uint256 public constant LOCK_VESTED_MIN_PERIOD = 365 days; // 1 year
    uint256 public constant LOCK_VESTED_MAX_PERIOD = 4 * 365 days; // 4 years

    struct Position {
        address beneficiary;
        uint256 amount;
        uint256 amountPaid;
        uint256 vestingStart;
        uint256 vestingEnd;
        bool lockVested;
    }

    address public immutable underlying;

    address public voteEscrow;

    uint256 public totalVesting;

    Counters.Counter private _currentPositionId;

    Position[] public positions;

    mapping(address => uint256[]) public userPositionIndexes;

    event VoteEscrowSet(address indexed _admin, address _voteEscrow);

    event PositionCreated(
        address indexed _admin,
        address indexed _beneficiary,
        uint256 indexed _positionId,
        uint256 _amount,
        uint256 _vestingStart,
        uint256 _vestingEnd,
        bool lockVested
    );

    event AmountClaimed(address indexed _by, address indexed _recipient, uint256 _amount, uint256 _voteLockPeriod);

    constructor(address _underlying) {
        require(
            IERC165(_underlying).supportsInterface(type(IERC20).interfaceId),
            "Underlying should be IERC20 compatible"
        );
        underlying = _underlying;
    }

    function setVoteEscrow(address _voteEscrow) external onlyOwner {
        voteEscrow = _voteEscrow;
        emit VoteEscrowSet(_msgSender(), _voteEscrow);
    }

    function totalSupply() public view returns (uint256) {
        return IERC20(underlying).balanceOf(address(this));
    }

    function usableSupply() public view returns (uint256) {
        return totalSupply() - totalVesting;
    }

    function createPosition(
        address _beneficiary,
        uint256 _amount,
        uint256 _cliffPeriod,
        uint256 _vestingDuration,
        bool _lockVested
    ) external onlyOwner {
        require(_beneficiary != address(0), "Invalid beneficiary");
        require(
            _vestingDuration >= MIN_VESTING_PERIOD && _vestingDuration <= MAX_VESTING_PERIOD,
            "Invalid vesting duration"
        );
        require(usableSupply() >= _amount, "Insufficient underlying");
        uint256 vestingStart = block.timestamp + _cliffPeriod;
        uint256 vestingEnd = vestingStart + _vestingDuration;
        positions.push(
            Position({
                beneficiary: _beneficiary,
                amount: _amount,
                amountPaid: 0,
                vestingStart: vestingStart,
                vestingEnd: vestingEnd,
                lockVested: _lockVested
            })
        );
        uint256 currentPositionId = _currentPositionId.current();
        userPositionIndexes[_beneficiary].push(currentPositionId);
        _currentPositionId.increment();

        emit PositionCreated(
            _msgSender(),
            _beneficiary,
            currentPositionId,
            _amount,
            vestingStart,
            vestingEnd,
            _lockVested
        );
    }

    function claim(
        uint256 _positionId,
        address _recipient,
        uint256 _lockVestedPeriod
    ) external {
        Position memory userPosition = positions[_positionId];
        require(userPosition.beneficiary == _msgSender(), "Invalid position");
        require(userPosition.vestingStart >= block.timestamp, "Vesting hasn't started");
        require(_recipient != address(0), "Invalid recipient");
        uint256 amountDue = ((((block.timestamp - userPosition.vestingStart) * userPosition.amount) * BASE_MULTIPLIER) /
            (userPosition.vestingEnd - userPosition.vestingStart)) /
            BASE_MULTIPLIER -
            userPosition.amountPaid;
        if (amountDue == 0) return;
        if (userPosition.lockVested || _lockVestedPeriod > 0) {
            require(voteEscrow != address(0), "No vote escrow");
            require(
                _lockVestedPeriod >= MIN_VESTING_PERIOD && _lockVestedPeriod <= MAX_VESTING_PERIOD,
                "Invalid lock time"
            );
            IERC20(underlying).safeTransfer(voteEscrow, amountDue);
            // TODO: Implement logic to lock amountDue tokens to _recipient on Vote Escrow contract
            return;
        }
        IERC20(underlying).safeTransfer(_recipient, amountDue);

        emit AmountClaimed(_msgSender(), _recipient, amountDue, _lockVestedPeriod);
    }
}
