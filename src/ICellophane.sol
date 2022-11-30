// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

interface ICellophane {
    function wrap(address tokenAddress, uint256 tokenId, address owner) external returns (uint256);
    function wrap(address tokenAddress, uint256 tokenId, address owner, bytes32 salt) external returns (uint256);
    function derive(address tokenAddress, uint256 tokenId, address owner) external view returns (address);
    function derive(address tokenAddress, uint256 tokenId, address owner, bytes32 salt)
        external
        view
        returns (address);
    function unwrap(uint256 cellophaneTokenId) external;
}
