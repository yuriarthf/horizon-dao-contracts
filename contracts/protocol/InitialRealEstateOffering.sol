// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { CountersUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import { BitMapsUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/structs/BitMapsUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import { IRealEstateERC1155 } from "../interfaces/IRealEstateERC1155.sol";
import { IRealEstateReserves } from "../interfaces/IRealEstateReserves.sol";

/// @title Initial Real Estate Offering (IRO)
/// @author Horizon DAO (Yuri Fernandes)
/// @notice Used to run IROs, mint tokens to RealEstateNFT
///     and distribute funds
contract InitialRealEstateOffering is OwnableUpgradeable, UUPSUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;

    /// @dev Denominator used to calculate fees/shares
    uint16 public constant DENOMINATOR = 10000;

    /// @dev IRO status enum
    /// @dev Status descriptions:
    ///     - PENDING: IRO hasn't started
    ///     - ONGOING: IRO is active, commits are allowed
    ///     - SUCCESS: IRO has been successful, claiming is allowed
    ///     - FAIL: IRO failed, committed funds are withdrawable
    enum Status {
        PENDING,
        ONGOING,
        SUCCESS,
        FAIL
    }

    /// @dev Initial Real Estate Offerring structure
    /// @dev Since timestamps are 64 bit integers, last IRO
    ///     should finish at 21 de julho de 2554 11:34:33.709 UTC.
    /// @dev Field description:
    ///     - listingOwner: Address of the IRO listing owner
    ///     - start: IRO start time
    ///     - treasuryFee: Basis point treasury fee over total funds
    ///     - listingOwnerFee: Basis point listing owner fee over total funds
    ///     - end: IRO end time
    ///     - softCap: Minimum amount of funds necessary for the IRO to be
    ///         successful
    ///     - hardCap: Maximum amount of funds possible to the IRO
    ///     - unitPrice: IRO price per token
    ///     - totalFunding: Total amount of funds collected during an IRO
    ///     - currency: IRO currency, used as a security measurement, if
    ///         the contract-level currency has changed during active IROs
    struct IRO {
        address listingOwner;
        uint64 start;
        uint16 treasuryFee;
        uint16 listingOwnerFee;
        uint16 listingOwnerShare;
        uint64 end;
        uint256 softCap;
        uint256 hardCap;
        uint256 unitPrice;
        uint256 totalFunding;
        address currency;
    }

    /// @notice Currency address
    address public currency;

    /// @notice Treasury contract address
    address public treasury;

    /// @notice RealEstateNFT contract address
    IRealEstateERC1155 public realEstateNft;

    /// @notice RealEstateReserves contract address
    IRealEstateReserves public realEstateReserves;

    /// @dev Next available IRO ID
    CountersUpgradeable.Counter private _nextAvailableId;

    /// @dev mapping (iroId => iro)
    mapping(uint256 => IRO) private _iros;

    /// @dev mapping (iroId => user => commit)
    mapping(uint256 => mapping(address => uint256)) public commits;

    /// @dev mapping (iroId => realEstateId)
    mapping(uint256 => uint256) public realEstateId;

    /// @dev Points out whether funds have been withdrawn from IRO
    BitMapsUpgradeable.BitMap private _fundsWithdrawn;

    /// @dev Points out whether the listingOwner has claimed it's share
    BitMapsUpgradeable.BitMap private _listingOwnerClaimed;

    /// @dev Whether an ID has already been set in the RealEstateNFT contract for the IRO
    BitMapsUpgradeable.BitMap private _realEstateIdSet;

    /// @dev Emitted when a new IRO is created
    event CreateIRO(
        uint256 indexed _id,
        address indexed _listingOwner,
        uint256 _unitPrice,
        uint16 _listingOwnerShare,
        uint16 _treasuryFee,
        uint64 _start,
        uint64 _end
    );

    /// @dev Emitted when a new Commit is made to an IRO
    event Commit(
        uint256 indexed _iroId,
        address indexed _user,
        address indexed _currency,
        uint256 _amountInBase,
        uint256 _purchasedTokens
    );

    /// @dev Emitted when tokens are claimed by investors
    event TokensClaimed(uint256 indexed _iroId, address indexed _by, address indexed _to, uint256 _amount);

    /// @dev Emitted when the listing owner claims it's shares of the tokens
    event OwnerTokensClaimed(uint256 indexed _iroId, address indexed _by, address indexed _to, uint256 _amount);

    /// @dev Emitted when an investors withdraw it's funds after an IRO fails
    event CashBack(uint256 indexed _iroId, address indexed _by, address indexed _to, uint256 _commitAmount);

    /// @dev Emitted when a new currency is set
    event SetBaseCurrency(address indexed _by, address indexed _currency);

    /// @dev Emitted when the Treasury contract is set
    event SetTreasury(address indexed _by, address indexed _treasury);

    /// @dev Emitted when the RealEstateReserves contract is set
    event SetRealEstateReserves(address indexed _by, address indexed _realEstateReserves);

    /// @dev Emitted when a new real estate token ID is created
    event RealEstateCreated(uint256 indexed _iroId, uint256 indexed _realEstateId);

    /// @dev Emitted when funds from an IRO are withdrawn
    event FundsWithdrawn(
        uint256 indexed _iroId,
        address indexed _by,
        bool indexed _realEstateFundsSet,
        uint256 _listingOwnerAmount,
        uint256 _treasuryAmount,
        uint256 _realEstateFundsAmount
    );

    /// @dev Initialize IRO contract
    /// @param _realEstateNft RealEstateNFT contract address
    /// @param _treasury Treasury contract address
    /// @param _realEstateReserves RealEstateReserves contract address
    /// @param _currency Currency used to precify the IRO tokens
    /// @param _swapRouter Uniswap or Sushiswap swap router
    function initialize(
        address _owner,
        address _realEstateNft,
        address _treasury,
        address _realEstateReserves,
        address _currency,
        address _swapRouter
    ) external initializer {
        require(_realEstateNft != address(0), "!_realEstateNft");
        require(_treasury != address(0), "!_treasury");
        require(_currency != address(0), "!_currency");
        require(_swapRouter != address(0), "!_swapRouter");
        realEstateNft = IRealEstateERC1155(_realEstateNft);
        treasury = _treasury;
        currency = _currency;
        realEstateReserves = IRealEstateReserves(_realEstateReserves);
        _transferOwnership(_owner);
    }

    /// @dev Set a new base price token
    /// @param _currency currency address (ERC20)
    function setCurrency(address _currency) external onlyOwner {
        require(_currency != address(0), "!_currency");
        currency = _currency;
        emit SetBaseCurrency(msg.sender, _currency);
    }

    /// @dev Set new treasury
    /// @param _treasury Treasury address
    function setTreasury(address _treasury) external onlyOwner {
        require(_treasury != address(0), "!_treasury");
        treasury = _treasury;
        emit SetTreasury(msg.sender, _treasury);
    }

    /// @dev Set new real estate reserves
    /// @param _realEstateReserves RealEstateReseres address
    function setRealEstateReserves(address _realEstateReserves) external onlyOwner {
        require(_realEstateReserves != address(0), "!_realEstateReserves");
        realEstateReserves = IRealEstateReserves(_realEstateReserves);
        emit SetRealEstateReserves(msg.sender, _realEstateReserves);
    }

    /// @dev Create new IRO
    /// @param _listingOwner Listing owner address
    /// @param _listingOwnerFee Listing owner fee in basis points
    /// @param _listingOwnerShare Listing owner share of IRO tokens in basis points
    /// @param _treasuryFee Treasury fee percentage in basis points
    /// @param _duration Duration of the IRO in seconds
    /// @param _softCap Minimum fundraising in base price token
    /// @param _hardCap Maximum fundraising in base price token
    /// @param _unitPrice Price per unit of IRO token in base price token
    /// @param _startOffset Time before IRO begins
    function createIRO(
        address _listingOwner,
        uint16 _listingOwnerFee,
        uint16 _listingOwnerShare,
        uint16 _treasuryFee,
        uint64 _duration,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _unitPrice,
        uint64 _startOffset
    ) external onlyOwner {
        require(_listingOwnerShare <= DENOMINATOR, "Invalid basis point");
        require(_treasuryFee + _listingOwnerFee <= DENOMINATOR, "Fees should be less than 100%");
        require((_hardCap - _softCap) % _unitPrice == 0, "Caps should be multiples of unitPrice");

        uint256 currentId = iroLength();
        uint64 start_ = now64() + _startOffset;
        uint64 end_ = start_ + _duration;
        _iros[currentId] = IRO({
            listingOwner: _listingOwner,
            start: start_,
            treasuryFee: _treasuryFee,
            listingOwnerFee: _listingOwnerFee,
            listingOwnerShare: _listingOwnerShare,
            end: end_,
            softCap: _softCap,
            hardCap: _hardCap,
            unitPrice: _unitPrice,
            totalFunding: 0,
            currency: currency
        });
        _nextAvailableId.increment();

        emit CreateIRO(currentId, _listingOwner, _unitPrice, _listingOwnerShare, _treasuryFee, start_, end_);
    }

    /// @notice Commit to an IRO
    /// @param _iroId ID of the IRO
    /// @param _amountToPurchase Amount of IRO tokens to purchase
    function commit(uint256 _iroId, uint256 _amountToPurchase) external {
        require(_amountToPurchase > 0, "_amountToPurchase should be greater than zero");
        IRO memory iro = getIRO(_iroId);
        require(_getStatus(iro) == Status.ONGOING, "IRO is not active");
        require(iro.totalFunding + _amountToPurchase * iro.unitPrice <= iro.hardCap, "Hardcap reached");

        uint256 valueInBase = _processPayment(iro.unitPrice, _amountToPurchase, iro.currency);

        commits[_iroId][msg.sender] += valueInBase;
        _iros[_iroId].totalFunding += valueInBase;

        emit Commit(_iroId, msg.sender, iro.currency, valueInBase, _amountToPurchase);
    }

    /// @dev Enable receiving ETH
    receive() external payable {}

    /// @notice Claim purchased tokens when IRO successful or
    ///     get back commit amount in base currency if IRO failed
    /// @param _iroId ID of the IRO
    /// @param _to Address to send the claimed tokens
    function claim(uint256 _iroId, address _to) external {
        IRO memory iro = getIRO(_iroId);
        Status status = _getStatus(iro);
        require(status > Status.ONGOING, "IRO not finished");
        uint256 commitAmount = commits[_iroId][msg.sender];
        require(commitAmount > 0, "Nothing to mint");
        if (status == Status.SUCCESS) {
            uint256 amountToMint = commitAmount / iro.unitPrice;
            realEstateNft.mint(_retrieveRealEstateId(_iroId), _to, amountToMint);
            emit TokensClaimed(_iroId, msg.sender, _to, amountToMint);
        } else {
            IERC20Upgradeable(currency).safeTransfer(_to, commitAmount);
            commits[_iroId][msg.sender] = 0;
            emit CashBack(_iroId, msg.sender, _to, commitAmount);
        }
    }

    /// @notice Claim listing owner tokens
    /// @param _iroId ID of the IRO
    /// @param _to Address to send the tokens
    function listingOwnerClaim(uint256 _iroId, address _to) external {
        IRO memory iro = getIRO(_iroId);
        require(msg.sender == iro.listingOwner, "!allowed");
        require(!_listingOwnerClaimed.get(_iroId), "Already claimed");
        require(_getStatus(iro) == Status.SUCCESS, "IRO not successful");
        require(iro.listingOwnerShare > 0, "Nothing to claim");
        uint256 listingOwnerAmount_ = _listingOwnerAmount(iro.totalFunding, iro.unitPrice, iro.listingOwnerShare);
        realEstateNft.mint(_retrieveRealEstateId(_iroId), _to, listingOwnerAmount_);
        _listingOwnerClaimed.set(_iroId);
        emit OwnerTokensClaimed(_iroId, msg.sender, _to, listingOwnerAmount_);
    }

    /// @notice Withdraw and distribute funds from successful IROs
    /// @param _iroId ID of the IRO
    function withdraw(uint256 _iroId) external {
        IRO memory iro = getIRO(_iroId);
        require(_getStatus(iro) == Status.SUCCESS, "IRO not successful");
        require(!_fundsWithdrawn.get(_iroId), "Already withdrawn");
        (
            uint256 listingOwnerAmount_,
            uint256 treasuryAmount,
            uint256 realEstateReservesAmount,
            bool realEstateReservesSet
        ) = _distributeFunds(
                iro.listingOwner,
                treasury,
                realEstateReserves,
                _retrieveRealEstateId(_iroId),
                iro.totalFunding,
                iro.listingOwnerFee,
                iro.treasuryFee,
                iro.currency
            );
        _fundsWithdrawn.set(_iroId);
        emit FundsWithdrawn(
            _iroId,
            msg.sender,
            realEstateReservesSet,
            listingOwnerAmount_,
            treasuryAmount,
            realEstateReservesAmount
        );
    }

    /// @notice Get the total price of a purchase
    /// @param _iroId ID of the IRO
    /// @param _amountToPurchase Amount of IRO tokens to purchase
    function price(uint256 _iroId, uint256 _amountToPurchase) external view returns (uint256) {
        IRO memory iro = getIRO(_iroId);
        return _amountToPurchase * iro.unitPrice;
    }

    /// @notice Get the current total supply
    /// @param _iroId ID of the IRO
    function totalSupply(uint256 _iroId) external view returns (uint256) {
        IRO memory iro = getIRO(_iroId);
        return _calculateSupply(iro.totalFunding, iro.unitPrice, iro.listingOwnerShare);
    }

    /// @notice Get minimum and maximum supply
    /// @param _iroId ID of the IRO
    function totalSupplyInterval(
        uint256 _iroId
    ) external view returns (uint256 minTotalSupply, uint256 maxTotalSupply) {
        IRO memory iro = getIRO(_iroId);
        minTotalSupply = _calculateSupply(iro.softCap, iro.unitPrice, iro.listingOwnerShare);
        maxTotalSupply = _calculateSupply(iro.hardCap, iro.unitPrice, iro.listingOwnerShare);
    }

    /// @notice Get the amount of remaining IRO tokens
    /// @param _iroId ID of the IRO
    function remainingTokens(uint256 _iroId) external view returns (uint256) {
        IRO memory iro = getIRO(_iroId);
        return (iro.hardCap - iro.totalFunding) / iro.unitPrice;
    }

    /// @notice Get IRO status
    /// @param _iroId ID of the IRO
    function getStatus(uint256 _iroId) external view returns (Status) {
        IRO memory iro = _iros[_iroId];
        return _getStatus(iro);
    }

    /// @notice Get IRO
    /// @param _iroId ID of the IRO
    function getIRO(uint256 _iroId) public view returns (IRO memory) {
        require(_iroId < iroLength(), "_iroId out-of-bounds");
        return _iros[_iroId];
    }

    /// @notice Get current time (uint64)
    function now64() public view returns (uint64) {
        return uint64(block.timestamp);
    }

    /// @notice Get total amount of IROs
    function iroLength() public view returns (uint256) {
        return _nextAvailableId.current();
    }

    /// @notice Get current listing owner reNFT amount
    /// @param _iroId ID of the IRO
    function listingOwnerAmount(uint256 _iroId) public view returns (uint256 amount) {
        IRO memory iro = _iros[_iroId];
        amount = _listingOwnerAmount(iro.totalFunding, iro.unitPrice, iro.listingOwnerShare);
    }

    /// @dev Retrieve the realEstateId associated with a given IRO
    /// @dev If none is assigned, assigns a new one
    /// @param _iroId ID of the IRO
    function _retrieveRealEstateId(uint256 _iroId) internal returns (uint256 _realEstateId) {
        if (!_realEstateIdSet.get(_iroId)) {
            _realEstateId = realEstateNft.nextRealEstateId();
            realEstateId[_iroId] = _realEstateId;
            _realEstateIdSet.set(_iroId);
            emit RealEstateCreated(_iroId, _realEstateId);
        } else {
            _realEstateId = realEstateId[_iroId];
        }
    }

    /// @inheritdoc UUPSUpgradeable
    function _authorizeUpgrade(address newImplementation) internal virtual override onlyOwner {}

    /// @dev Get status of an IRO
    /// @param _iro IRO structure
    function _getStatus(IRO memory _iro) internal view returns (Status) {
        if (now64() <= _iro.start) return Status.PENDING;
        if (now64() < _iro.end) {
            if (_iro.totalFunding == _iro.hardCap) return Status.SUCCESS;
            return Status.ONGOING;
        }
        if (now64() >= _iro.end) {
            if (_iro.totalFunding < _iro.softCap) return Status.FAIL;
            return Status.SUCCESS;
        }
        return Status.FAIL;
    }

    /// @dev Calculate total supply
    /// @param _totalFunding Total IRO funding
    /// @param _unitPrice IRO token unit price
    /// @param _listingOwnerShare Listing owner token share
    function _calculateSupply(
        uint256 _totalFunding,
        uint256 _unitPrice,
        uint16 _listingOwnerShare
    ) internal pure returns (uint256) {
        return _totalFunding / _unitPrice + _listingOwnerAmount(_totalFunding, _unitPrice, _listingOwnerShare);
    }

    /// @dev Calculate listing owner amount
    /// @dev Should be less than 100% or it will overflows
    /// @param _totalFunding Total IRO funding
    /// @param _unitPrice IRO token unit price
    /// @param _share Listing owner token share
    /// @return amount Amount of tokens
    function _listingOwnerAmount(
        uint256 _totalFunding,
        uint256 _unitPrice,
        uint16 _share
    ) internal pure returns (uint256 amount) {
        uint256 totalPurchased = _totalFunding / _unitPrice;
        amount = (totalPurchased * _share) / (DENOMINATOR - _share);
    }

    /// @dev Process commit payment
    /// @param _unitPrice Unit price of the token
    /// @param _amountToPurchase Amount of tokens to purchase
    /// @param _currency Payment currency address
    function _processPayment(
        uint256 _unitPrice,
        uint256 _amountToPurchase,
        address _currency
    ) private returns (uint256 value) {
        value = _amountToPurchase * _unitPrice;
        IERC20Upgradeable(_currency).safeTransferFrom(msg.sender, address(this), value);
    }

    /// @dev Distribute funds during IRO withdrawal
    /// @param _listingOwner The listing owner of the IRO
    /// @param _treasury Treasury contract address
    /// @param _realEstateReserves RealEstateReserves contract address
    /// @param _realEstateId ID of the RealEstate token to receive the funds
    /// @param _totalFunding Total funds from the IRO
    /// @param _listingOwnerFee Fee requested by the listing owner
    /// @param _treasuryFee Treasury fee
    /// @param _currency IRO currency address
    function _distributeFunds(
        address _listingOwner,
        address _treasury,
        IRealEstateReserves _realEstateReserves,
        uint256 _realEstateId,
        uint256 _totalFunding,
        uint256 _listingOwnerFee,
        uint256 _treasuryFee,
        address _currency
    )
        private
        returns (
            uint256 listingOwnerAmount_,
            uint256 treasuryAmount,
            uint256 realEstateReservesAmount,
            bool realEstateReservesSet
        )
    {
        if (_listingOwnerFee > 0) {
            listingOwnerAmount_ = (_listingOwnerFee * _totalFunding) / DENOMINATOR;
            IERC20Upgradeable(_currency).safeTransfer(_listingOwner, listingOwnerAmount_);
        }
        treasuryAmount = (_treasuryFee * _totalFunding) / DENOMINATOR;
        realEstateReservesAmount = _totalFunding - (listingOwnerAmount_ + treasuryAmount);
        if (address(_realEstateReserves) != address(0)) {
            realEstateReservesSet = true;
            if (treasuryAmount > 0) {
                IERC20Upgradeable(_currency).safeTransfer(_treasury, treasuryAmount);
            }

            if (realEstateReservesAmount > 0) {
                IERC20Upgradeable(_currency).safeApprove(address(_realEstateReserves), realEstateReservesAmount);
                _realEstateReserves.deposit(_realEstateId, realEstateReservesAmount, _currency);
            }
        } else {
            IERC20Upgradeable(_currency).safeTransfer(_treasury, _totalFunding - listingOwnerAmount_);
        }
    }
}
