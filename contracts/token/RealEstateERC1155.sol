// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import { SafeERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import { ERC1155Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/ERC1155Upgradeable.sol";
import { IERC1155MetadataURIUpgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC1155/extensions/IERC1155MetadataURIUpgradeable.sol";
import { BitMapsUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/structs/BitMapsUpgradeable.sol";
import { CountersUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import { StringsUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/StringsUpgradeable.sol";
import { AddressUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import { RoyalERC1155Upgradeable } from "./RoyalERC1155Upgradeable.sol";

/// @title Real Estate NFT
/// @author Yuri Fernandes (HorizonDAO)
/// @notice Used to Tokenize and Fractionate Real Estate
/// @notice Only minter can mint tokens and set token metadata
/// @notice New tokens should be minted by incrementing the tokenId by 1
contract RealEstateERC1155 is RoyalERC1155Upgradeable {
    using BitMapsUpgradeable for BitMapsUpgradeable.BitMap;
    using CountersUpgradeable for CountersUpgradeable.Counter;
    using StringsUpgradeable for uint256;
    using AddressUpgradeable for address;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @dev Structure to auxiliate yield calculation
    struct Deposit {
        uint256 unlockedAmountPerToken;
        uint256 lockedAmount;
        uint128 unlockStart;
        uint128 unlockEnd;
    }

    /// @dev Address of the minter: Can execute mint function
    address public minter;

    /// @dev Address of the burner: Can execute burn function
    address public burner;

    /// @dev Address of the depositor: Can execute deposit function
    address public depositor;

    /// @dev Current value shows the next available token ID
    CountersUpgradeable.Counter private _currentId;

    /// @dev Currency used to pay yield
    address public yieldCurrency;

    /// @dev mapping (tokenId => Deposit)
    mapping(uint256 => Deposit) private _deposits;

    /// @dev mapping (tokenId => account => yieldPerTokenClaimed)
    mapping(uint256 => mapping(address => uint256)) public yieldPerTokenClaimed;

    /// @dev mapping (tokenId => account => yieldBalance)
    mapping(uint256 => mapping(address => uint256)) public yieldBalance;

    /// @dev Emitted when a new minter is set
    event SetMinter(address indexed _by, address indexed _minter);

    /// @dev Emitted when a new burner is set
    event SetBurner(address indexed _by, address indexed _burner);

    /// @dev Emitted when a new depositor is set
    event SetDepositor(address indexed _by, address indexed _depositor);

    /// @dev Emitted when new reNFTs are minted
    event RealEstateNFTMinted(uint256 indexed _id, address indexed _minter, address indexed _to, uint256 _amount);

    /// @dev Emitted when reNFTs are burned
    event RealEstateNFTBurned(
        uint256 indexed _id,
        address indexed _originAccount,
        address indexed _burner,
        uint256 _amount
    );

    /// @dev Emitted when yield is deposited
    event NewDeposit(
        uint256 indexed _id,
        address indexed _depositor,
        uint256 _amount,
        uint128 _unlockStart,
        uint128 _unlockEnd
    );

    /// @dev Emitted when yield is claimed
    event ClaimYield(uint256 indexed _id, address indexed _by, address indexed _to, uint256 _yieldClaimed);

    /// @dev Initialize RealEstateNFT
    /// @param _uri Standard (fallback) URI for the offchain NFT metadata
    /// @param _admin Address with contract administration privileges
    /// @param _owner EOA to be used as OpenSea token admin
    function initialize(string memory _uri, address _admin, address _owner, address _yieldCurrency) public initializer {
        __RoyalERC1155_init(_uri, _admin, _owner);
        yieldCurrency = _yieldCurrency;
    }

    /// @dev Set new Yield Currency contract
    /// @dev Should be used with caution and maybe changed or removed before production,
    ///     since changing it might invalidate previous yield deposits
    /// @param _yieldCurrency Address of the ERC20 used for yield deposits and claims
    function setYieldCurrency(address _yieldCurrency) external onlyAdmin {
        require(yieldCurrency != _yieldCurrency, "Same Yield Currency");
        yieldCurrency = _yieldCurrency;
    }

    /// @notice Returns the name of the RealEstateERC1155 contract
    function name() external pure returns (string memory) {
        return "Real Estate NFT";
    }

    /// @notice Returns the symbol of the RealEstateERC1155 contract
    function symbol() external pure returns (string memory) {
        return "reNFT";
    }

    /// @notice Returns the ID of the next available reNFT
    function nextRealEstateId() external view returns (uint256) {
        return _currentId.current();
    }

    /// @dev Set new minter role
    /// @param _minter New minter address
    function setMinter(address _minter) external onlyAdmin {
        require(minter != _minter, "Same minter");
        minter = _minter;
        emit SetMinter(_msgSender(), _minter);
    }

    /// @dev Set new burner role
    /// @param _burner New burner address
    function setBurner(address _burner) external onlyAdmin {
        require(burner != _burner, "Same burner");
        burner = _burner;
        emit SetBurner(_msgSender(), _burner);
    }

    function setDepositor(address _depositor) external onlyAdmin {
        require(depositor != _depositor, "Same depositor");
        depositor = _depositor;
        emit SetDepositor(_msgSender(), _depositor);
    }

    /// @dev Mint new reNFT tokens
    /// @dev Requires Minter role
    /// @param _id Token ID
    /// @param _to Address to transfer minted tokens
    /// @param _amount Amount to mint
    function mint(uint256 _id, address _to, uint256 _amount) external {
        require(_msgSender() == minter, "!minter");
        if (totalSupply(_id) == 0) {
            require(_id == 0 || totalSupply(_id - 1) > 0, "IDs should be sequential");
            _currentId.increment();
        } else {
            _updateDeposit(_id);
        }
        _mint(_to, _id, _amount, bytes(""));
        emit RealEstateNFTMinted(_id, _msgSender(), _to, _amount);
    }

    /// @dev Deposit yield to a given token ID
    /// @param _id Token ID
    /// @param _amount Amount to deposit
    /// @param _duration Time to distribute the cumulative yield
    /// @param _startOffset Period of time before yield starts to cumulate
    function deposit(uint256 _id, uint256 _amount, uint128 _duration, uint128 _startOffset) external {
        require(_msgSender() == depositor, "!depositor");
        require(_amount > 0, "!deposit");
        IERC20Upgradeable(yieldCurrency).safeTransferFrom(_msgSender(), address(this), _amount);
        Deposit memory deposit_ = _deposits[_id];
        uint256 unlockedYield = _unlockableYield(deposit_);
        uint128 unlockStart = now128() + _startOffset;
        _deposits[_id].unlockedAmountPerToken += unlockedYield / totalSupply(_id);
        _deposits[_id].lockedAmount = (deposit_.lockedAmount - unlockedYield) + _amount;
        _deposits[_id].unlockStart = unlockStart;
        _deposits[_id].unlockEnd = unlockStart + _duration;
        emit NewDeposit(_id, _msgSender(), _amount, unlockStart, unlockStart + _duration);
    }

    /// @notice Claim Yield for a given token ID
    /// @param _id Token ID
    /// @param _to Yield receiver
    function claimYield(uint256 _id, address _to) external {
        _update(_id, _msgSender());
        uint256 userYieldBalance = yieldBalance[_id][_msgSender()];
        yieldBalance[_id][_msgSender()] = 0;
        IERC20Upgradeable(yieldCurrency).safeTransfer(_to, userYieldBalance);
        emit ClaimYield(_id, _msgSender(), _to, userYieldBalance);
    }

    /// @dev Burns own tokens (will be used for buyouts)
    /// @dev Requires Burner role
    /// @param _id Token ID
    /// @param _originAccount Origin account of the tokens
    /// @param _amount Amount of tokens to burn
    function burn(uint256 _id, address _originAccount, uint256 _amount) external {
        require(_msgSender() == burner, "!burner");
        _burnerHelper(_id, _originAccount, _amount);
        _burn(_msgSender(), _id, _amount);
        emit RealEstateNFTBurned(_id, _originAccount, _msgSender(), _amount);
    }

    /// @notice Get the amount of yield pending for a given token ID and account
    /// @param _id Token ID
    /// @param _account Account to check for pending yield
    function pendingYield(uint256 _id, address _account) external view returns (uint256) {
        uint256 yieldPerToken_ = yieldPerToken(_id);
        return
            yieldBalance[_id][_account] +
            balanceOf(_account, _id) *
            (yieldPerToken_ - yieldPerTokenClaimed[_id][_account]);
    }

    /// @notice Current time limited to 128 bits
    function now128() public view returns (uint128) {
        return uint128(block.timestamp);
    }

    /// @notice Get current yield per token
    /// @param _id Token ID
    function yieldPerToken(uint256 _id) public view returns (uint256) {
        Deposit memory deposit_ = _deposits[_id];
        uint256 totalSupply_ = totalSupply(_id);
        if (totalSupply_ == 0) return 0;
        return deposit_.unlockedAmountPerToken + _unlockableYield(deposit_) / totalSupply_;
    }

    /// @dev Updated yield for an account
    /// @param _id Token ID
    /// @param _account Account to update yield
    function _update(uint256 _id, address _account) internal {
        if (_account == address(0)) return;
        uint256 yieldPerToken_ = yieldPerToken(_id);
        yieldBalance[_id][_account] +=
            balanceOf(_account, _id) *
            (yieldPerToken_ - yieldPerTokenClaimed[_id][_account]);
        yieldPerTokenClaimed[_id][_account] = yieldPerToken_;
    }

    /// @dev Update deposit information (when totalSupply changes)
    /// @param _id Token ID
    function _updateDeposit(uint256 _id) internal {
        Deposit memory deposit_ = _deposits[_id];
        if (deposit_.lockedAmount == 0 || now128() <= deposit_.unlockStart) return;
        uint256 totalSupply_ = totalSupply(_id);
        if (totalSupply_ == 0) return;
        uint256 unlockedYield = _unlockableYield(deposit_);
        _deposits[_id].lockedAmount -= unlockedYield;
        _deposits[_id].unlockedAmountPerToken += unlockedYield / totalSupply_;
        if (now128() <= deposit_.unlockEnd) _deposits[_id].unlockStart = now128();
    }

    /// @dev Get the unlockable yield
    /// @param _deposit Deposit object to get the unlockable yield
    function _unlockableYield(Deposit memory _deposit) internal view returns (uint256) {
        if (now128() <= _deposit.unlockStart) return 0;
        if (now128() >= _deposit.unlockEnd) return _deposit.lockedAmount;
        uint128 unlockDuration = _deposit.unlockEnd - _deposit.unlockStart;
        return (_deposit.lockedAmount * (now128() - _deposit.unlockStart)) / unlockDuration;
    }

    /// @dev Do the necessary operations before burning tokens
    /// @param _id Token ID
    /// @param _originAccount Origin account of the tokens
    /// @param _amount Amount of tokens to burn
    function _burnerHelper(uint256 _id, address _originAccount, uint256 _amount) internal {
        _updateDeposit(_id);
        uint256 yieldPerToken_ = yieldPerToken(_id);
        yieldBalance[_id][_originAccount] +=
            (balanceOf(_originAccount, _id) + _amount) *
            (yieldPerToken_ - yieldPerTokenClaimed[_id][_originAccount]);
        yieldPerTokenClaimed[_id][_originAccount] = yieldPerToken_;
    }

    /// @dev Extended _beforeTokenTransfer to update accounts' yield balance
    /// @dev See {ERC1155-_beforeTokenTransfer}
    function _beforeTokenTransfer(
        address _operator,
        address _from,
        address _to,
        uint256[] memory _ids,
        uint256[] memory _amounts,
        bytes memory _data
    ) internal virtual override {
        super._beforeTokenTransfer(_operator, _from, _to, _ids, _amounts, _data);
        for (uint256 i = 0; i < _ids.length; i++) {
            _update(_ids[i], _from);
            _update(_ids[i], _to);
        }
    }

    /**
     * @dev This empty reserved space is put in place to allow future versions to add new
     * variables without shifting down storage in the inheritance chain.
     * See https://docs.openzeppelin.com/contracts/4.x/upgradeable#storage_gaps
     */
    uint256[42] private __gap;
}
