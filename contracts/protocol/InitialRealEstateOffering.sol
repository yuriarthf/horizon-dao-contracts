// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";

import { FeedRegistryInterface } from "@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol";

import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import { IROFinance } from "../libraries/IROFinance.sol";

contract InitialRealEstateOffering is Ownable {
    using Counters for Counters.Counter;
    using IROFinance for IROFinance.Finance;

    uint16 public constant FEE_BASIS_POINT = 10000;
    uint16 public constant SHARE_BASIS_POINT = 10000;
    uint64 public constant PERIOD = 1 days;
    uint64 public constant MIN_NUMBER_OF_PERIODS = 30; // 30 days

    /// @dev Initial Real Estate Offerring structure
    /// @dev Since timestamps are 64 bit integers, last IRO
    ///     should finish at 21 de julho de 2554 11:34:33.709 UTC.
    struct IRO {
        address listingOwner;
        uint64 start;
        uint16 treasuryFee;
        uint16 listingOwnerShare;
        uint64 end;
        uint256 softCap;
        uint256 hardCap;
        uint256 unitPrice;
        uint256 totalFunding;
    }

    address public treasury;
    address public realEstateNft;

    IROFinance.Finance public finance;

    Counters.Counter private _nextAvailableId;

    /// @dev mapping (iroId => iro)
    mapping(uint256 => IRO) public iros;

    /// @dev mapping (iroId => user => commit)
    mapping(uint256 => mapping(address => uint256)) public commits;

    /// @dev mapping (iroId => period => totalFunding)
    mapping(uint256 => uint256[]) public totalFundingPerPeriod;

    event TogglePaymentToken(address indexed _by, address indexed _paymentToken, bool indexed allowed);

    event CreateIRO(
        uint256 indexed _id,
        address indexed _listingOwner,
        uint256 _unitPrice,
        uint16 _listingOwnerShare,
        uint16 _treasuryFee,
        uint64 _start,
        uint64 _end
    );

    event Commit(
        uint256 indexed _iroId,
        address indexed _user,
        address indexed _paymentToken,
        uint256 _amountInBase,
        uint256 _purchasedTokens
    );

    constructor(
        address _realEstateNft,
        address _treasury,
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
        realEstateNft = _realEstateNft;
        treasury = _treasury;
        finance.swapRouter = IUniswapV2Router02(_swapRouter);
        finance.priceFeedRegistry = FeedRegistryInterface(_priceFeedRegistry);
        finance.weth = _weth;
        finance.basePriceToken = _basePriceToken;
    }

    function setBasePriceToken(address _basePriceToken) external onlyOwner {
        require(_basePriceToken != address(0), "!_basePriceToken");
        finance.basePriceToken = _basePriceToken;
    }

    function createIRO(
        address _listingOwner,
        uint16 _listingOwnerShare,
        uint16 _treasuryFee,
        uint64 _numberOfPeriods,
        uint256 _softCap,
        uint256 _hardCap,
        uint256 _unitPrice,
        uint64 _startOffset
    ) external onlyOwner {
        require(_numberOfPeriods >= MIN_NUMBER_OF_PERIODS, "!_numberOfPeriods");
        require(_listingOwnerShare <= SHARE_BASIS_POINT, "!_listingOwnerShare");
        require(_treasuryFee <= FEE_BASIS_POINT, "!_treasuryFee");
        require(_softCap <= _hardCap, "_softCap > _hardCap");

        uint256 currentId = iroLength();
        uint64 start_ = now64() + _startOffset;
        uint64 end_ = start_ + _numberOfPeriods * PERIOD;
        iros[currentId] = IRO({
            listingOwner: _listingOwner,
            start: start_,
            treasuryFee: _treasuryFee,
            listingOwnerShare: _listingOwnerShare,
            end: end_,
            softCap: _softCap,
            hardCap: _hardCap,
            unitPrice: _unitPrice,
            totalFunding: 0
        });
        _nextAvailableId.increment();

        emit CreateIRO(currentId, _listingOwner, _unitPrice, _listingOwnerShare, _treasuryFee, start_, end_);
    }

    function commit(
        uint256 _iroId,
        address _paymentToken,
        uint256 _amountToPurchase,
        uint16 _slippage
    ) external payable {
        require(_amountToPurchase > 0, "_amountToBuy should be greater than zero");
        require(_slippage <= IROFinance.SLIPPAGE_DIVISOR, "Invalid _slippage");
        IRO memory iro = getIRO(_iroId);
        require(_isIroActive(iro), "IRO is inactive");
        require(iro.totalFunding + _amountToPurchase <= iro.hardCap, "Hardcap reached");
        if (_paymentToken != address(0) && msg.value > 0) {
            IROFinance.sendValue(msg.sender, msg.value);
        }

        uint256 valueInBase = finance.processPayment(iro.unitPrice, _amountToPurchase, _paymentToken, _slippage);

        commits[_iroId][msg.sender] += _amountToPurchase;
        iros[_iroId].totalFunding += valueInBase;

        emit Commit(_iroId, msg.sender, _paymentToken, valueInBase, _amountToPurchase);
    }

    function maxSlippage() external pure returns (uint16) {
        return IROFinance.SLIPPAGE_DIVISOR;
    }

    function iroFinished(uint256 _iroId) external view returns (bool) {
        return now64() >= getIRO(_iroId).end;
    }

    function getIRO(uint256 _iroId) public view returns (IRO memory) {
        require(_iroId < iroLength(), "_iroId out-of-bounds");
        return iros[_iroId];
    }

    function getCurrentPeriod(uint256 _iroId) public view returns (uint64) {
        return _getCurrentPeriod(iros[_iroId]);
    }

    function now64() public view returns (uint64) {
        return uint64(block.timestamp);
    }

    function iroLength() public view returns (uint256) {
        return _nextAvailableId.current();
    }

    function isIroActive(uint256 _iroId) public view returns (bool) {
        IRO memory iro = getIRO(_iroId);
        return _isIroActive(iro);
    }

    function _isIroActive(IRO memory _iro) internal view returns (bool) {
        return now64() >= _iro.start && now64() < _iro.end;
    }

    function _getCurrentPeriod(IRO memory _iro) internal view returns (uint64) {
        require(now64() < _iro.end, "IRO finished");
        if (now64() < _iro.start) return 0;
        return (now64() - _iro.start) / PERIOD + 1;
    }
}
