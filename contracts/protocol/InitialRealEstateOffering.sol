// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";
import { BitMaps } from "@openzeppelin/contracts/utils/structs/BitMaps.sol";

import { IRealEstateERC1155 } from "../interfaces/IRealEstateERC1155.sol";
import { IRealEstateFunds } from "../interfaces/IRealEstateFunds.sol";
import { IROFinance } from "../libraries/IROFinance.sol";

/// @title Initial Real Estate Offering (IRO)
/// @author Horizon DAO (Yuri Fernandes)
/// @notice Used to run IROs, mint tokens to RealEstateNFT
///     and distribute funds
contract InitialRealEstateOffering is Ownable {
    using Counters for Counters.Counter;
    using BitMaps for BitMaps.BitMap;
    using IROFinance for IROFinance.Finance;

    /// @dev IRO status enum
    enum Status {
        PENDING,
        ONGOING,
        SUCCESS,
        FAIL
    }

    /// @dev Initial Real Estate Offerring structure
    /// @dev Since timestamps are 64 bit integers, last IRO
    ///     should finish at 21 de julho de 2554 11:34:33.709 UTC.
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
    }

    /// @notice Treasury contract address
    address public treasury;

    /// @notice RealEstateNFT contract address
    IRealEstateERC1155 public realEstateNft;

    /// @notice RealEstateFunds contract address
    IRealEstateFunds public realEstateFunds;

    /// @notice Structure composed by the addresses
    ///     of contracts responsible for making financial operations
    IROFinance.Finance public finance;

    /// @dev Next available IRO ID
    Counters.Counter private _nextAvailableId;

    /// @dev mapping (iroId => iro)
    mapping(uint256 => IRO) private _iros;

    /// @dev mapping (iroId => user => commit)
    mapping(uint256 => mapping(address => uint256)) public commits;

    /// @dev mapping (iroId => realEstateId)
    mapping(uint256 => uint256) public realEstateId;

    /// @dev mapping (currencyAddress => whitelited)
    mapping(address => bool) public whitelistedCurrency;

    /// @dev Points out whether funds have been withdrawn from IRO
    BitMaps.BitMap private _fundsWithdrawn;

    /// @dev Points out whether the listingOwner has claimed it's share
    BitMaps.BitMap private _listingOwnerClaimed;

    /// @dev Whether an ID has already been set in the RealEstateNFT contract for the IRO
    BitMaps.BitMap private _realEstateIdSet;

    /// @dev Emitted when a new payment token is added
    event TogglePaymentToken(address indexed _by, address indexed _paymentToken, bool indexed allowed);

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
        address indexed _paymentToken,
        uint256 _amountInBase,
        uint256 _purchasedTokens
    );

    /// @dev Emitted when `whitelistCurrency` is executed
    event WhitelistCurrency(address indexed _by, address indexed _currency, bool indexed _whitelist);

    /// @dev Emitted when tokens are claimed by investors
    event TokensClaimed(uint256 indexed _iroId, address indexed _by, address indexed _to, uint256 _amount);

    /// @dev Emitted when the listing owner claims it's shares of the tokens
    event OwnerTokensClaimed(uint256 indexed _iroId, address indexed _by, address indexed _to, uint256 _amount);

    /// @dev Emitted when an investors withdraw it's funds after an IRO fails
    event CashBack(uint256 indexed _iroId, address indexed _by, address indexed _to, uint256 _commitAmount);

    /// @dev Emitted when funds from an IRO are withdrawn
    event FundsWithdrawn(
        uint256 indexed _iroId,
        address indexed _by,
        uint256 _listingOwnerAmount,
        uint256 _treasuryAmount,
        uint256 _realEstateFundsAmount
    );

    /// @dev Initialize IRO contract
    /// @param _realEstateNft RealEstateNFT contract address
    /// @param _treasury Treasury contract address
    /// @param _realEstateFunds RealEstateFunds contract address
    /// @param _basePriceToken Base token used to precify the IRO tokens
    /// @param _priceFeedRegistry Chainlink Price Feed Registry address
    /// @param _swapRouter Uniswap or Sushiswap swap router
    /// @param _weth WETH contract address
    constructor(
        address _realEstateNft,
        address _treasury,
        address _realEstateFunds,
        address _basePriceToken,
        address _priceFeedRegistry,
        address _swapRouter,
        address _weth
    ) {
        require(_realEstateNft != address(0), "!_realEstateNft");
        require(_treasury != address(0), "!_treasury");
        require(_basePriceToken != address(0), "!_basePriceToken");
        require(_priceFeedRegistry != address(0), "!_priceFeedRegistry");
        require(_swapRouter != address(0), "!_swapRouter");
        require(_weth != address(0), "!_weth");
        realEstateNft = IRealEstateERC1155(_realEstateNft);
        treasury = _treasury;
        realEstateFunds = IRealEstateFunds(_realEstateFunds);
        finance.initializeFinance(_swapRouter, _priceFeedRegistry, _weth, _basePriceToken);
    }

    /// @dev Set a new base price token
    /// @param _basePriceToken Base price token address (ERC20)
    function setBasePriceToken(address _basePriceToken) external onlyOwner {
        require(_basePriceToken != address(0), "!_basePriceToken");
        finance.basePriceToken = _basePriceToken;
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
        require(_listingOwnerShare <= IROFinance.SHARE_DENOMINATOR, "Invalid owner share");
        require(_treasuryFee <= IROFinance.FEE_DENOMINATOR, "Invalid treasury fee");
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
            totalFunding: 0
        });
        _nextAvailableId.increment();
        whitelistedCurrency[address(0)] = true;

        emit CreateIRO(currentId, _listingOwner, _unitPrice, _listingOwnerShare, _treasuryFee, start_, end_);
    }

    /// @notice Commit to an IRO
    /// @param _iroId ID of the IRO
    /// @param _paymentToken Payment token address
    /// @param _amountToPurchase Amount of IRO tokens to purchase
    /// @param _slippage Slippage in basis points when swapping token by
    ///     base payment token (not applicable when paying directly with it)
    function commit(
        uint256 _iroId,
        address _paymentToken,
        uint256 _amountToPurchase,
        uint16 _slippage
    ) external payable {
        require(_amountToPurchase > 0, "_amountToBuy should be greater than zero");
        require(_paymentToken == finance.basePriceToken || whitelistedCurrency[_paymentToken], "Currency not allowed");
        require(_slippage <= IROFinance.SLIPPAGE_DENOMINATOR, "Invalid _slippage");
        IRO memory iro = getIRO(_iroId);
        require(_getStatus(iro) == Status.ONGOING, "IRO is not active");
        require(iro.totalFunding + _amountToPurchase * iro.unitPrice <= iro.hardCap, "Hardcap reached");
        if (_paymentToken != address(0) && msg.value > 0) {
            IROFinance.sendEther(msg.sender, msg.value);
        }

        uint256 valueInBase = finance.processPayment(iro.unitPrice, _amountToPurchase, _paymentToken, _slippage);

        commits[_iroId][msg.sender] += _amountToPurchase;
        _iros[_iroId].totalFunding += valueInBase;

        emit Commit(_iroId, msg.sender, _paymentToken, valueInBase, _amountToPurchase);
    }

    /// @notice Claim purchased tokens when IRO successful or
    ///     get back commit amount in base payment tokens if IRO failed
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
            realEstateNft.mint(_retrieveRealEstateId(_iroId), msg.sender, amountToMint);
            emit TokensClaimed(_iroId, msg.sender, _to, amountToMint);
        } else {
            IROFinance.sendErc20(_to, commitAmount, finance.basePriceToken);
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
        uint256 listingOwnerAmount = IROFinance.shareToAmount(iro.totalFunding, iro.unitPrice, iro.listingOwnerShare);
        realEstateNft.mint(_retrieveRealEstateId(_iroId), _to, listingOwnerAmount);
        _listingOwnerClaimed.set(_iroId);
        emit OwnerTokensClaimed(_iroId, msg.sender, _to, listingOwnerAmount);
    }

    /// @notice Withdraw and distribute funds from successful IROs
    /// @param _iroId ID of the IRO
    function withdraw(uint256 _iroId) external {
        IRO memory iro = getIRO(_iroId);
        require(_getStatus(iro) == Status.SUCCESS, "IRO not successful");
        require(!_fundsWithdrawn.get(_iroId), "Already withdrawn");
        (uint256 listingOwnerAmount, uint256 treasuryAmount, uint256 realEstateFundsAmount) = finance.distributeFunds(
            iro.listingOwner,
            treasury,
            realEstateFunds,
            _retrieveRealEstateId(_iroId),
            iro.totalFunding,
            iro.listingOwnerFee,
            iro.treasuryFee
        );
        _fundsWithdrawn.set(_iroId);
        emit FundsWithdrawn(_iroId, msg.sender, listingOwnerAmount, treasuryAmount, realEstateFundsAmount);
    }

    /// @dev Whitelist payment currencies
    /// @param _currency Currency ERC20 address
    /// @param _whitelist Whether to whitelist
    function whitelistCurrency(address _currency, bool _whitelist) external onlyOwner {
        require(_currency != address(0), "!invalid address");
        whitelistedCurrency[_currency] = _whitelist;
        emit WhitelistCurrency(msg.sender, _currency, _whitelist);
    }

    /// @notice Get the expected price of an IRO purchase (without slippage)
    /// @param _iroId ID of the IRO
    /// @param _paymentToken Payment token address
    /// @param _amountToPurchase Amount of IRO tokens to purchase
    function expectedPrice(
        uint256 _iroId,
        address _paymentToken,
        uint256 _amountToPurchase
    ) external view returns (uint256) {
        IRO memory iro = getIRO(_iroId);
        uint256 valueInBase = _amountToPurchase * iro.unitPrice;
        if (_paymentToken == finance.basePriceToken) {
            return valueInBase;
        }
        return finance.convertBaseToPaymentToken(valueInBase, _paymentToken);
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

    /// @notice Check slippage denominator
    function slippageDenominator() external pure returns (uint16) {
        return IROFinance.SLIPPAGE_DENOMINATOR;
    }

    /// @notice Check fee denominator
    function feeDenominator() external pure returns (uint16) {
        return IROFinance.FEE_DENOMINATOR;
    }

    /// @notice Check share denominator
    function shareDenominator() external pure returns (uint16) {
        return IROFinance.SHARE_DENOMINATOR;
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

    /// @dev Retrieve the realEstateId associated with a given IRO
    /// @dev If none is assigned, assigns a new one
    /// @param _iroId ID of the IRO
    function _retrieveRealEstateId(uint256 _iroId) internal returns (uint256 _realEstateId) {
        if (!_realEstateIdSet.get(_iroId)) {
            _realEstateId = realEstateNft.nextRealEstateId();
            realEstateId[_iroId] = _realEstateId;
            _realEstateIdSet.set(_iroId);
        } else {
            _realEstateId = realEstateId[_iroId];
        }
    }

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
}
