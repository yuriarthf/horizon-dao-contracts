// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import { IERC165 } from "@openzeppelin/contracts/interfaces/IERC165.sol";
import { IERC20 } from "@openzeppelin/contracts/interfaces/IERC20.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import { Counters } from "@openzeppelin/contracts/utils/Counters.sol";

/// @dev EIP-2612 (Permit extension for ERC20)
abstract contract ERC20Permit is ERC20, IERC165 {
    using Counters for Counters.Counter;

    /// @dev Typehash for the domain separator
    /// @dev keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
    bytes32 public constant EIP712_DOMAIN_TYPEHASH = 0x8b73c3c69bb8fe3d512ecc4cf759cc79239f7b179b0ffacaa9a75d522b39400f;

    /// @dev Typehash for the permit function
    /// @dev keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")
    bytes32 public constant PERMIT_TYPEHASH = 0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;

    /// @dev mapping (account => permitNonce)
    /// @dev Used to avoid repeated permit usage
    mapping(address => Counters.Counter) private _nonces;

    /// @dev EIP-712 domain separator
    bytes32 public immutable DOMAIN_SEPARATOR;

    /// @dev Initialize ERC20Permit contract
    /// @param _name Token name
    /// @param _symbol Token symbol
    constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
        // set domain separator
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(EIP712_DOMAIN_TYPEHASH, keccak256(bytes(_name)), keccak256("1"), block.chainid, address(this))
        );
    }

    /// @notice Sets `_value` as the allowance of `_spender` over the owners's tokens.
    /// @notice Anyone with a signed permit message hash by the `_owner`, can execute this function.
    /// @param _owner Token owner address
    /// @param _spender Spender address
    /// @param _value Amount to give allowance to `_spender`
    /// @param _deadline EIP-712 signed message validity
    /// @param _signature EIP-712 signature
    function permit(
        address _owner,
        address _spender,
        uint256 _value,
        uint256 _deadline,
        bytes memory _signature
    ) external {
        require(block.timestamp <= _deadline, "ERC20Permit: deadline reached");

        uint256 nonce = _nonces[_owner].current();
        bytes32 permitHash = ECDSA.toTypedDataHash(
            DOMAIN_SEPARATOR,
            keccak256(abi.encode(PERMIT_TYPEHASH, _owner, _spender, _value, nonce, _deadline))
        );

        require(ECDSA.recover(permitHash, _signature) == _owner, "ERC20Permit: invalid permit");

        _nonces[_owner].increment();
        _approve(_owner, _spender, _value);
    }

    /// @dev Current valid nonce for an user
    /// @param _owner User address
    function nonces(address _owner) external view returns (uint256) {
        return _nonces[_owner].current();
    }

    /// @inheritdoc IERC165
    function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
        return type(IERC165).interfaceId == interfaceId || type(IERC20).interfaceId == interfaceId;
    }
}
