// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import { FeedRegistryInterface } from "@chainlink/contracts/src/v0.8/interfaces/FeedRegistryInterface.sol";
import { Denominations } from "@chainlink/contracts/src/v0.8/Denominations.sol";

import { IUniswapV2Router02 } from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface IERC20Extended is IERC20 {
    function decimals() external view returns (uint8);
}

contract InitialRealEstateOffering is Ownable {
    using Counters for Counters.Counter;
    using SafeERC20 for IERC20;

    uint16 public constant FEE_BASIS_POINT = 10000;
    uint16 public constant SHARE_BASIS_POINT = 10000;
    uint64 public constant PERIOD = 1 days;
    uint64 public constant MIN_NUMBER_OF_PERIODS = 30; // 30 days

    struct Commit {
        uint128 amountOfTokens;
        uint64 periodNumber;
        uint256 accumulatedRewards;
    }

    /// @dev Initial Real Estate Offerring structure
    /// @dev Since timestamps are 64 bit integers, last IRO
    ///     should finish at 21 de julho de 2554 11:34:33.709 UTC.
    struct IRO {
        address listingOwner;
        uint64 start;
        uint16 treasuryFee;
        uint16 listingOwnerShare;
        uint128 minSupply;
        uint128 maxSupply;
        uint256 unitPrice;
        uint64 end;
        uint256 rewardsPerPeriod;
        uint256 totalFunding;
    }

    address public treasury;
    address public realEstateNft;
    address public basePriceToken;

    IUniswapV2Router02 public swapRouter;
    FeedRegistryInterface public priceFeedRegistry;
    address public weth;

    Counters.Counter private _nextAvailableId;

    /// @dev mapping (iroId => iro)
    mapping(uint256 => IRO) public iros;

    /// @dev mapping (iroId => user => commit)
    mapping(uint256 => mapping(address => Commit)) public commits;

    /// @dev mapping (iroId => period => totalFunding)
    mapping(uint256 => uint256[]) public totalFundingPerPeriod;

    event TogglePaymentToken(address indexed _by, address indexed _paymentToken, bool indexed allowed);

    event CreateIRO(
        uint256 indexed _id,
        address indexed _listingOwner,
        uint256 _unitPrice,
        uint16 _listingOwnerShare,
        uint16 _treasuryFee,
        uint256 _rewardsPerPeriod
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
        basePriceToken = _basePriceToken;
        priceFeedRegistry = FeedRegistryInterface(_priceFeedRegistry);
        swapRouter = IUniswapV2Router02(_swapRouter);
        weth = _weth;
    }

    function setBasePriceToken(address _basePriceToken) external onlyOwner {
        require(_basePriceToken != address(0), "!_basePriceToken");
        basePriceToken = _basePriceToken;
    }

    function createIRO(
        address _listingOwner,
        uint16 _listingOwnerShare,
        uint16 _treasuryFee,
        uint64 _numberOfPeriods,
        uint128 _minSupply,
        uint128 _maxSupply,
        uint256 _unitPrice,
        uint64 _startOffset,
        uint256 _incentives
    ) external onlyOwner {
        require(_numberOfPeriods >= MIN_NUMBER_OF_PERIODS, "!_numberOfPeriods");
        require(_listingOwnerShare <= SHARE_BASIS_POINT, "!_listingOwnerShare");
        require(_treasuryFee <= FEE_BASIS_POINT, "!_treasuryFee");
        require(_minSupply <= _maxSupply, "!_minSupply");

        uint256 currentId = iroLength();
        uint256 rewardsPerPeriod = _incentives / _numberOfPeriods;
        iros[currentId] = IRO({
            listingOwner: _listingOwner,
            start: now64() + _startOffset,
            treasuryFee: _treasuryFee,
            listingOwnerShare: _listingOwnerShare,
            minSupply: _minSupply,
            maxSupply: _maxSupply,
            unitPrice: _unitPrice,
            end: now64() + _startOffset + _numberOfPeriods * PERIOD,
            rewardsPerPeriod: rewardsPerPeriod,
            totalFunding: 0
        });
        _nextAvailableId.increment();

        IERC20(basePriceToken).safeTransferFrom(msg.sender, address(this), rewardsPerPeriod * _numberOfPeriods);

        emit CreateIRO(currentId, _listingOwner, _unitPrice, _listingOwnerShare, _treasuryFee, rewardsPerPeriod);
    }

    function commitToIRO(uint256 _iroId, uint256 _value, address _paymentToken) external payable {
        require(_value > 0, "_value should be greater than 0");
        IRO memory iro = getIRO(_iroId);
        require(_isIroActive(iro), "IRO is inactive");

        uint128 purchasingAmount;
        if (_paymentToken == basePriceToken) {
            purchasingAmount = uint128(_value / iro.unitPrice);
            require(purchasingAmount > 0, "Insufficient payment");
            IERC20(_paymentToken).safeTransferFrom(msg.sender, address(this), purchasingAmount * iro.unitPrice);
        } else {
            uint256 effectiveValue;
            if (_paymentToken != address(0)) {
                (, int256 priceInBase, , , ) = priceFeedRegistry.latestRoundData(_paymentToken, basePriceToken);
                uint256 baseQuote = uint256(_scalePrice(priceInBase, basePriceToken));
                uint256 paymentTokenDecimals = 10 ** uint256(IERC20Extended(_paymentToken).decimals());
                purchasingAmount = uint128(((_value * baseQuote) / iro.unitPrice) / paymentTokenDecimals);
                require(purchasingAmount > 0, "Insufficient payment");
                effectiveValue = uint256((purchasingAmount * iro.unitPrice * paymentTokenDecimals) / baseQuote);
                IERC20(_paymentToken).safeTransferFrom(msg.sender, address(this), effectiveValue);
                IERC20(_paymentToken).safeApprove(address(swapRouter), effectiveValue);
                address[] memory path = new address[](2);
                path[0] = _paymentToken;
                path[1] = basePriceToken;
                swapRouter.swapExactTokensForTokens(
                    effectiveValue,
                    purchasingAmount * iro.unitPrice,
                    path,
                    address(this),
                    block.timestamp
                );
            } else {
                (, int256 priceInBase, , , ) = priceFeedRegistry.latestRoundData(Denominations.ETH, basePriceToken);
                uint256 baseQuote = uint256(_scalePrice(priceInBase, basePriceToken));
                purchasingAmount = uint128(((_value * baseQuote) / iro.unitPrice) / 10 ** 18);
                require(purchasingAmount > 0, "Insufficient payment");
                effectiveValue = uint256((purchasingAmount * iro.unitPrice * 10 ** 18) / baseQuote);
                address[] memory path = new address[](2);
                path[0] = weth;
                path[1] = basePriceToken;
                swapRouter.swapExactETHForTokens{ value: effectiveValue }(
                    purchasingAmount * iro.unitPrice,
                    path,
                    address(this),
                    block.timestamp
                );
                _sendValue(msg.sender, msg.value - effectiveValue);
            }
        }

        // Update commit (don't forget to accumulate rewards before adding value in case the last commit period is over)
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

    function _scalePrice(int256 _price, address _token) internal view returns (int256) {
        uint8 priceDecimals = priceFeedRegistry.decimals(
            _token != address(0) ? _token : Denominations.ETH,
            basePriceToken
        );
        uint8 tokenDecimals = IERC20Extended(_token).decimals();
        if (priceDecimals < tokenDecimals) {
            return _price * int256(10 ** uint256(tokenDecimals - priceDecimals));
        } else if (priceDecimals > tokenDecimals) {
            return _price * int256(10 ** uint256(priceDecimals - tokenDecimals));
        }
        return _price;
    }

    /// @dev Utility function to send an amount of ethers to a given address
    /// @param _to Address to send ethers
    /// @param _amount Amount of ethers to send
    function _sendValue(address _to, uint256 _amount) internal {
        (bool success, ) = _to.call{ value: _amount }("");
        require(success, "Failed sending ethers");
    }
}
