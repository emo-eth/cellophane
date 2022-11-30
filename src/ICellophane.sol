// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

/**
 * @title  ICellophane
 * @author emo.eth
 * @notice Interface for the Cellophane smart contract.
 */
interface ICellophane {
    struct WrappedToken {
        /// @dev The smart contract address of the wrapped ERC721 token
        address tokenAddress;
        /// @dev The ID of the wrapped ERC721 token
        uint256 tokenId;
        /// @dev The salt used to derive the deposit address, derived by hashing the depositor's address with a
        ///      different salt
        bytes32 salt;
    }

    function deriveDepositAddress(address tokenAddress, uint256 tokenId, address owner)
        external
        view
        returns (address);
    function deriveDepositAddress(address tokenAddress, uint256 tokenId, address owner, uint256 salt)
        external
        view
        returns (address);
    function deriveDepositDelegateAddress(address tokenAddress, uint256 tokenId, address depositor)
        external
        view
        returns (address);
    function deriveDepositDelegateAddress(address tokenAddress, uint256 tokenId, address depositor, uint256 salt)
        external
        view
        returns (address);
    function wrap(address tokenAddress, uint256 tokenId, address owner) external returns (uint256);
    function wrap(address tokenAddress, uint256 tokenId, address owner, uint256 salt) external returns (uint256);
    function deposit(address tokenAddress, uint256 tokenId) external;
    function deposit(address tokenAddress, uint256 tokenId, uint256 salt) external;
    function depositAndWrap(address tokenAddress, uint256 tokenId) external returns (uint256);
    function depositAndWrap(address tokenAddress, uint256 tokenId, uint256 salt) external returns (uint256);
    function unwrap(uint256 cellophaneTokenId) external;
    function isTokenWrapped(address tokenAddress, uint256 tokenId) external view returns (bool);
    function getWrappedTokenId(address tokenAddress, uint256 tokenId) external view returns (uint256);
    function getWrappedToken(uint256 cellophaneTokenId) external view returns (WrappedToken memory);
}
