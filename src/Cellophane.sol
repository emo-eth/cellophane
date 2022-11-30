// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ICellophane} from "./ICellophane.sol";
import {CounterfactualUnwrapper} from "./CounterfactualUnwrapper.sol";
import {CounterfactualTransferDelegate} from "./CounterfactualTransferDelegate.sol";

/**
 * @title  Cellophane
 * @author emo.eth
 * @notice Cellophane is a proof-of-concept counterfactual ERC721 token wrapper.
 *
 *         Cellophane differs from conventional token wrappers because tokens are never deposited into, or directly
 *         transferred by, the Cellophane smart contract.
 *
 *         All token transfers happen within the constructors of counterfactual smart contracts in order to bypass
 *         `EXTCODESIZE` and `EXTCODEHASH` checks. Cellophane thus is particularly immune to attempts to restrict
 *         operators using a deny-list, but is still thwarted by much more restrictive [allow-list and CAPTCHA based
 *         approaches](https://github.com/transmissions11/ERC721C) (which generally break token composability).
 */
contract Cellophane is ICellophane, ERC721 {
    error AlreadyWrapped(uint256 tokenId);
    error NotWrapped(uint256 tokenId);
    error OriginalTokenNotInCounterfactualContainer();
    error UnableToDeployCounterfactualUnwrapper();
    error UnableToDeployCounterfactualTransferDelegate();
    error NotOwner(uint256 tokenId);

    mapping(uint256 => WrappedToken) internal _wrappedTokens;

    constructor() ERC721("Cellophane", "CELL") {}

    function tokenURI(uint256) public pure override returns (string memory) {
        return "";
    }

    /**
     * @notice Derive the deposit address for a given token and mint the corresponding wrapped token to `owner` if the
     *         token exists at the derived address and is not already wrapped.
     */
    function wrap(address tokenAddress, uint256 tokenId, address owner) public override returns (uint256) {
        return wrap(tokenAddress, tokenId, owner, 0);
    }

    /**
     * @notice Derive the deposit address for a given token using a given salt and mint the corresponding wrapped
     *         token to `owner` if the token exists at the derived address and is not already wrapped.
     */
    function wrap(address tokenAddress, uint256 tokenId, address owner, uint256 salt)
        public
        override
        returns (uint256)
    {
        uint256 cellophaneTokenId = uint256(keccak256(abi.encodePacked(tokenAddress, tokenId)));
        if (_ownerOf[cellophaneTokenId] != address(0)) {
            revert AlreadyWrapped(cellophaneTokenId);
        }

        bytes32 compoundSalt = keccak256(abi.encodePacked(owner, salt));
        address derivedAddress = _deriveDepositAddress(tokenAddress, tokenId, compoundSalt);
        address originalTokenOwner = ERC721(tokenAddress).ownerOf(tokenId);
        if (originalTokenOwner != derivedAddress) {
            revert OriginalTokenNotInCounterfactualContainer();
        }

        _wrappedTokens[cellophaneTokenId] = WrappedToken(tokenAddress, tokenId, compoundSalt);
        _mint(owner, cellophaneTokenId);
        return cellophaneTokenId;
    }

    /**
     * @notice If the caller owns the supplied Cellophane tokenId, deploy the CounterfactualUnwrapper to the deposit
     *         address to unwrap the original token. Burns the Cellophane token.
     */
    function unwrap(uint256 cellophaneTokenId) public override {
        if (ownerOf(cellophaneTokenId) != msg.sender) {
            revert NotOwner(cellophaneTokenId);
        }
        WrappedToken memory wrappedToken = _wrappedTokens[cellophaneTokenId];
        address tokenAddress = wrappedToken.tokenAddress;
        uint256 tokenId = wrappedToken.tokenId;
        bytes32 salt = wrappedToken.salt;

        bytes memory initCode = abi.encodePacked(
            type(CounterfactualUnwrapper).creationCode,
            abi.encode(tokenAddress, tokenId, _cellophaneTokenId(tokenAddress, tokenId))
        );
        address createdAddress;
        /// @solidity memory-safe-assembly
        assembly {
            let encoded_data := add(0x20, initCode) // load initialization code.
            let encoded_size := mload(initCode) // load the init code's length.
            createdAddress :=
                create2( // call CREATE2 with 4 arguments.
                    0, // forward no value
                    encoded_data, // pass in initialization code.
                    encoded_size, // pass in init code's length.
                    salt // use specified salt
                )
        }
        if (createdAddress == address(0)) {
            revert UnableToDeployCounterfactualUnwrapper();
        }
        delete _wrappedTokens[cellophaneTokenId];
        _burn(cellophaneTokenId);
    }

    /**
     * @notice Deploy a CounterfactualTransferDelegate to transfer the given token from the caller to its corresponding
     *         deposit address.
     */
    function deposit(address tokenAddress, uint256 tokenId) public override {
        return deposit(tokenAddress, tokenId, 0);
    }

    /**
     * @notice Deploy a CounterfactualTransferDelegate to transfer the given token from the caller to its corresponding
     *         deposit address using a given salt.
     */
    function deposit(address tokenAddress, uint256 tokenId, uint256 salt) public override {
        bytes32 compoundSalt = keccak256(abi.encodePacked(msg.sender, salt));
        address depositAddress = _deriveDepositAddress(tokenAddress, tokenId, compoundSalt);
        bytes memory initCode = abi.encodePacked(
            type(CounterfactualTransferDelegate).creationCode,
            abi.encode(tokenAddress, tokenId, msg.sender, depositAddress)
        );
        address createdAddress;
        /// @solidity memory-safe-assembly
        assembly {
            let encoded_data := add(0x20, initCode) // load initialization code.
            let encoded_size := mload(initCode) // load the init code's length.
            createdAddress :=
                create2( // call CREATE2 with 4 arguments.
                    0, // forward no value
                    encoded_data, // pass in initialization code.
                    encoded_size, // pass in init code's length.
                    compoundSalt
                )
        }
        if (createdAddress == address(0)) {
            revert UnableToDeployCounterfactualTransferDelegate();
        }
    }

    /**
     * @notice Deposits the given token to its corresponding deposit address and mints the corresponding wrapped token
     *         to the caller.
     */
    function depositAndWrap(address tokenAddress, uint256 tokenId) public override returns (uint256) {
        return depositAndWrap(tokenAddress, tokenId, 0);
    }

    /**
     * @notice Deposits the given token to its corresponding deposit address and mints the corresponding wrapped token
     *         to the caller using a given salt.
     */
    function depositAndWrap(address tokenAddress, uint256 tokenId, uint256 salt) public override returns (uint256) {
        deposit(tokenAddress, tokenId, salt);
        return wrap(tokenAddress, tokenId, msg.sender, salt);
    }

    /**
     * @notice Derive the deposit address for a given owner (initial depositor)
     */
    function deriveDepositAddress(address tokenAddress, uint256 tokenId, address owner)
        public
        view
        override
        returns (address)
    {
        return deriveDepositAddress(tokenAddress, tokenId, owner, 0);
    }

    /**
     * @notice Derive the deposit address for a given owner (initial depositor) and salt
     */
    function deriveDepositAddress(address tokenAddress, uint256 tokenId, address owner, uint256 salt)
        public
        view
        override
        returns (address)
    {
        bytes32 compoundSalt = keccak256(abi.encodePacked(owner, salt));
        return _deriveDepositAddress(tokenAddress, tokenId, compoundSalt);
    }

    /**
     * @notice Derive the deposit address for a given token using a given salt
     */
    function _deriveDepositAddress(address tokenAddress, uint256 tokenId, bytes32 salt)
        internal
        view
        returns (address)
    {
        bytes32 initCodeHash = keccak256(
            abi.encodePacked(
                type(CounterfactualUnwrapper).creationCode,
                abi.encode(tokenAddress, tokenId, _cellophaneTokenId(tokenAddress, tokenId))
            )
        );
        return _deriveAddress(salt, initCodeHash);
    }

    /**
     * @notice Derive the address that must be granted approval in order to deposit a given token from a depositor.
     */
    function deriveDepositDelegateAddress(address tokenAddress, uint256 tokenId, address depositor)
        public
        view
        override
        returns (address)
    {
        return deriveDepositDelegateAddress(tokenAddress, tokenId, depositor, 0);
    }

    /**
     * @notice Derive the address that must be granted approval in order to deposit a given token from a depositor
     *         using a given salt.
     */
    function deriveDepositDelegateAddress(address tokenAddress, uint256 tokenId, address depositor, uint256 salt)
        public
        view
        override
        returns (address)
    {
        bytes32 compoundSalt = keccak256(abi.encodePacked(depositor, salt));
        address derivedDepositAddress = _deriveDepositAddress(tokenAddress, tokenId, compoundSalt);
        bytes32 initCodeHash = keccak256(
            abi.encodePacked(
                type(CounterfactualTransferDelegate).creationCode,
                abi.encode(tokenAddress, tokenId, depositor, derivedDepositAddress)
            )
        );
        return _deriveAddress(compoundSalt, initCodeHash);
    }

    /**
     * @notice Given a token contract address and a token ID, determine if the token is currently wrapped.
     */
    function isTokenWrapped(address tokenAddress, uint256 tokenId) public view override returns (bool) {
        return _ownerOf[_cellophaneTokenId(tokenAddress, tokenId)] != address(0);
    }

    /**
     * @notice Given a token contract address and a token ID, determine its hypothetical wrapped token ID.
     *         Note that the token may not be currently wrapped.
     */
    function getWrappedTokenId(address tokenAddress, uint256 tokenId) public pure override returns (uint256) {
        return _cellophaneTokenId(tokenAddress, tokenId);
    }

    /**
     * @notice Given a Cellophaned token ID, return the stored information about the wrapped token.
     */
    function getWrappedToken(uint256 cellophaneTokenId) public view override returns (WrappedToken memory) {
        WrappedToken memory wrappedToken = _wrappedTokens[cellophaneTokenId];
        if (wrappedToken.tokenAddress == address(0)) {
            revert NotWrapped(cellophaneTokenId);
        }
        return wrappedToken;
    }

    function _cellophaneTokenId(address tokenAddress, uint256 tokenId) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(tokenAddress, tokenId)));
    }

    function _deriveAddress(bytes32 salt, bytes32 initCodeHash) internal view returns (address) {
        return address(
            uint160( // downcast to match the address type.
                uint256( // convert to uint to truncate upper digits.
                    keccak256( // compute the CREATE2 hash using 4 inputs.
                        abi.encodePacked( // pack all inputs to the hash together.
                            hex"ff", // start with 0xff to distinguish from RLP.
                            address(this), // this contract will be the caller.
                            salt, // pass in salt
                            initCodeHash // pass in the hash of initialization code.
                        )
                    )
                )
            )
        );
    }
}
