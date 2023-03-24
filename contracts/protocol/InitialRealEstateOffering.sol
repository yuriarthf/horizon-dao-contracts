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
        FUNDING,
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
    ///     - reservesFee: Basis point real estate reserves fee over total funds
    ///     - end: IRO end time
    ///     - currency: IRO currency, used as a security measurement, if
    ///         the contract-level currency has changed during active IROs
    ///     - targetCap: Target funding for the IRO to be successful
    ///     - unitPrice: IRO price per token
    ///     - totalFunding: Total amount of funds collected during an IRO
    struct IRO {
        address listingOwner;
        uint64 start;
        uint64 end;
        address currency;
        uint256 treasuryFee;
        uint256 operationFee;
        uint256 targetFunding;
        uint256 unitPrice;
        uint256 totalFunding;
    }

    /// @notice Currency address
    address public currency;

    /// @notice Treasury contract address
    address public treasury;

    /// @notice RealEstateNFT contract address
    IRealEstateERC1155 public realEstateNft;

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

    /// @dev Whether an ID has already been set in the RealEstateNFT contract for the IRO
    BitMapsUpgradeable.BitMap private _realEstateIdSet;

    /// @dev Emitted when a new IRO is created
    event CreateIRO(
        uint256 indexed _iroId,
        address indexed _listingOwner,
        address indexed _currency,
        uint64 _start,
        uint64 _end,
        uint256 _unitPrice,
        uint256 _targetFunding
    );

    /// @dev Emitted when a new Commit is made to an IRO
    event Commit(
        uint256 indexed _iroId,
        address indexed _user,
        address indexed _currency,
        uint256 _value,
        uint256 _purchasedAmount
    );

    /// @dev Emitted when tokens are claimed by investors
    event TokensClaimed(uint256 indexed _iroId, address indexed _by, address indexed _to, uint256 _amount);

    /// @dev Emitted when an investors withdraw it's funds after an IRO fails
    event CashBack(uint256 indexed _iroId, address indexed _by, address indexed _to, uint256 _commitAmount);

    /// @dev Emitted when a new currency is set
    event SetBaseCurrency(address indexed _by, address indexed _currency);

    /// @dev Emitted when the Treasury contract is set
    event SetTreasury(address indexed _by, address indexed _treasury);

    /// @dev Emitted when a new real estate token ID is created
    event RealEstateCreated(uint256 indexed _iroId, uint256 indexed _realEstateId);

    /// @dev Emitted when funds from an IRO are withdrawn
    event FundsWithdrawn(
        uint256 indexed _iroId,
        address indexed _by,
        uint256 _listingOwnerAmount,
        uint256 _treasuryFee,
        uint256 _operationFee
    );

    /// @dev Initialize IRO contract
    /// @param _realEstateNft RealEstateNFT contract address
    /// @param _treasury Treasury contract address
    /// @param _currency Currency used to precify the IRO tokens
    function initialize(
        address _owner,
        address _realEstateNft,
        address _treasury,
        address _currency
    ) external initializer {
        require(_realEstateNft != address(0), "!_realEstateNft");
        require(_treasury != address(0), "!_treasury");
        require(_currency != address(0), "!_currency");
        realEstateNft = IRealEstateERC1155(_realEstateNft);
        treasury = _treasury;
        currency = _currency;
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

    /// @dev Create new IRO
    /// @param _listingOwner Listing owner address
    /// @param _treasuryFee Treasury fee in absolute value
    /// @param _operationFee Operation fee in the IRO currency
    /// @param _duration Duration of the IRO in seconds
    /// @param _assetPrice Price of the asset
    /// @param _unitPrice Price per unit of IRO token in the IRO currency
    /// @param _startOffset Time before IRO begins
    function createIRO(
        address _listingOwner,
        uint256 _treasuryFee,
        uint256 _operationFee,
        uint64 _duration,
        uint256 _assetPrice,
        uint256 _unitPrice,
        uint64 _startOffset
    ) external onlyOwner {
        uint256 targetFunding = _assetPrice + _operationFee + _treasuryFee;
        require(
            (targetFunding / _unitPrice) * _unitPrice == targetFunding,
            "Target funding should be divisible by unit price"
        );

        uint256 currentId = iroLength();
        uint64 start_ = now64() + _startOffset;
        uint64 end_ = start_ + _duration;
        _iros[currentId] = IRO({
            listingOwner: _listingOwner,
            start: start_,
            end: end_,
            currency: currency,
            treasuryFee: _treasuryFee,
            operationFee: _operationFee,
            targetFunding: targetFunding,
            unitPrice: _unitPrice,
            totalFunding: 0
        });
        _nextAvailableId.increment();

        emit CreateIRO(currentId, _listingOwner, currency, start_, end_, _unitPrice, targetFunding);
    }

    /// @notice Commit to an IRO
    /// @param _iroId ID of the IRO
    /// @param _amountToPurchase Amount of IRO tokens to purchase
    function commit(uint256 _iroId, uint256 _amountToPurchase) external {
        require(_amountToPurchase > 0, "_amountToPurchase should be greater than zero");
        IRO memory iro = getIRO(_iroId);
        require(_getStatus(iro) == Status.FUNDING, "IRO is not active");
        require(iro.totalFunding + _amountToPurchase * iro.unitPrice <= iro.targetFunding, "Target funding reached");

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
        require(status > Status.FUNDING, "IRO not finished");
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

    /// @notice Withdraw and distribute funds from successful IROs
    /// @param _iroId ID of the IRO
    function withdraw(uint256 _iroId) external {
        IRO memory iro = getIRO(_iroId);
        require(_getStatus(iro) == Status.SUCCESS, "IRO not successful");
        require(!_fundsWithdrawn.get(_iroId), "Already withdrawn");

        uint256 listingOwnerAmount_ = _distributeFunds(iro);
        _fundsWithdrawn.set(_iroId);

        emit FundsWithdrawn(_iroId, msg.sender, listingOwnerAmount_, iro.treasuryFee, iro.operationFee);
    }

    /// @notice Get an user purchased amount and shares of an IRO
    /// @param _iroId ID of the IRO
    /// @param _user User address
    /// @return amount Purchased amount
    /// @return share IRO share
    function userAmountAndShare(uint256 _iroId, address _user) external view returns (uint256 amount, uint16 share) {
        IRO memory iro = getIRO(_iroId);
        uint256 userCommit = commits[_iroId][_user];
        amount = userCommit / iro.unitPrice;
        share = uint16((amount * DENOMINATOR) / _calculateSupply(iro.totalFunding, iro.unitPrice));
    }

    /// @notice Get the targetCap composition
    /// @param _iroId ID of the IRO
    function targetCapInfo(
        uint256 _iroId
    )
        external
        view
        returns (
            uint256 assetPrice,
            uint256 treasuryFee,
            uint256 operationFee,
            uint16 treasuryFeeBps,
            uint16 operationFeeBps
        )
    {
        IRO memory iro = _iros[_iroId];
        treasuryFee = iro.treasuryFee;
        operationFee = iro.operationFee;
        assetPrice = iro.targetFunding - (treasuryFee + operationFee);
        treasuryFeeBps = uint16((treasuryFee * DENOMINATOR) / assetPrice);
        operationFeeBps = uint16((operationFee * DENOMINATOR) / assetPrice);
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
    function currentTotalSupply(uint256 _iroId) external view returns (uint256) {
        IRO memory iro = getIRO(_iroId);
        return _calculateSupply(iro.totalFunding, iro.unitPrice);
    }

    /// @notice Get the total supply of an IRO, if successful
    /// @param _iroId ID of the IRO
    function expectedTotalSupply(uint256 _iroId) external view returns (uint256 expectedTotalSupply_) {
        IRO memory iro = getIRO(_iroId);
        expectedTotalSupply_ = _calculateSupply(iro.targetFunding, iro.unitPrice);
    }

    /// @notice Get the amount of remaining IRO tokens
    /// @param _iroId ID of the IRO
    function remainingTokens(uint256 _iroId) external view returns (uint256) {
        IRO memory iro = getIRO(_iroId);
        return (iro.targetFunding - iro.totalFunding) / iro.unitPrice;
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

    /// @dev Calculate supply
    /// @param _totalFunding Total funding amount
    /// @param _unitPrice IRO token unit price
    function _calculateSupply(uint256 _totalFunding, uint256 _unitPrice) internal pure returns (uint256) {
        return _totalFunding / _unitPrice;
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
        if (now64() < _iro.start) return Status.PENDING;
        if (now64() < _iro.end) {
            if (_iro.totalFunding == _iro.targetFunding) return Status.SUCCESS;
            return Status.FUNDING;
        }
        if (_iro.totalFunding < _iro.targetFunding) return Status.FAIL;
        return Status.SUCCESS;
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
    /// @param _iro IRO instance

    function _distributeFunds(IRO memory _iro) private returns (uint256 listingOwnerAmount_) {
        // transfer treasury and operation fee
        uint256 treasuryAmount = _iro.treasuryFee + _iro.operationFee;
        IERC20Upgradeable(_iro.currency).safeTransfer(treasury, treasuryAmount);

        // transfer listing owner funds
        listingOwnerAmount_ = _iro.targetFunding - treasuryAmount;
        IERC20Upgradeable(_iro.currency).safeTransfer(treasury, listingOwnerAmount_);
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[41] private __gap;
}
