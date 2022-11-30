// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "solmate/tokens/ERC721.sol";
import {ICellophane} from "./ICellophane.sol";
import {CounterfactualUnwrapper} from "./CounterfactualUnwrapper.sol";

contract Cellophane is ICellophane, ERC721 {
    error AlreadyWrapped(uint256 tokenId);
    error OriginalTokenNotInCounterfactualContainer();
    error UnableToDeployCounterfactualUnwrapper();
    error NotOwner(uint256 tokenId);

    struct WrappedToken {
        address tokenAddress;
        uint256 tokenId;
        bytes32 salt;
    }

    mapping(uint256 => WrappedToken) public wrappedTokens;

    constructor() ERC721("Cellophane", "CELL") {}

    function tokenURI(uint256) public pure override returns (string memory) {
        return "https://cellophane.art";
    }

    function wrap(address tokenAddress, uint256 tokenId, address owner) public override returns (uint256) {
        return wrap(tokenAddress, tokenId, owner, 0);
    }

    function wrap(address tokenAddress, uint256 tokenId, address owner, bytes32 salt)
        public
        override
        returns (uint256)
    {
        uint256 cellophaneTokenId = uint256(keccak256(abi.encodePacked(tokenAddress, tokenId)));
        if (_ownerOf[cellophaneTokenId] != address(0)) {
            revert AlreadyWrapped(cellophaneTokenId);
        }

        bytes32 compoundSalt = keccak256(abi.encodePacked(owner, salt));
        address derivedAddress = derive(tokenAddress, tokenId, compoundSalt);
        address originalTokenOwner = ERC721(tokenAddress).ownerOf(tokenId);
        if (originalTokenOwner != derivedAddress) {
            revert OriginalTokenNotInCounterfactualContainer();
        }

        wrappedTokens[cellophaneTokenId] = WrappedToken(tokenAddress, tokenId, compoundSalt);
        _mint(owner, cellophaneTokenId);
        return cellophaneTokenId;
    }

    function _cellophaneId(address tokenAddress, uint256 tokenId) internal pure returns (uint256) {
        return uint256(keccak256(abi.encodePacked(tokenAddress, tokenId)));
    }

    function derive(address tokenAddress, uint256 tokenId, address owner) public view override returns (address) {
        return derive(tokenAddress, tokenId, owner, 0);
    }

    function derive(address tokenAddress, uint256 tokenId, address owner, bytes32 salt)
        public
        view
        override
        returns (address)
    {
        bytes32 compoundSalt = keccak256(abi.encodePacked(owner, salt));
        return derive(tokenAddress, tokenId, compoundSalt);
    }

    function derive(address tokenAddress, uint256 tokenId, bytes32 salt) internal view returns (address) {
        bytes32 initCodeHash = keccak256(
            abi.encodePacked(
                type(CounterfactualUnwrapper).creationCode,
                abi.encode(tokenAddress, tokenId, _cellophaneId(tokenAddress, tokenId))
            )
        );
        return address(
            uint160( // downcast to match the address type.
                uint256( // convert to uint to truncate upper digits.
                    keccak256( // compute the CREATE2 hash using 4 inputs.
                        abi.encodePacked( // pack all inputs to the hash together.
                            hex"ff", // start with 0xff to distinguish from RLP.
                            address(this), // this contract will be the caller.
                            salt, // use hash of owner and salt as salt.
                            initCodeHash // pass in the hash of initialization code.
                        )
                    )
                )
            )
        );
    }

    function unwrap(uint256 cellophaneTokenId) public override {
        if (ownerOf(cellophaneTokenId) != msg.sender) {
            revert NotOwner(cellophaneTokenId);
        }
        WrappedToken memory wrappedToken = wrappedTokens[cellophaneTokenId];
        address tokenAddress = wrappedToken.tokenAddress;
        uint256 tokenId = wrappedToken.tokenId;
        bytes32 salt = wrappedToken.salt;

        bytes memory initCode = abi.encodePacked(
            type(CounterfactualUnwrapper).creationCode,
            abi.encode(tokenAddress, tokenId, _cellophaneId(tokenAddress, tokenId))
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
                    salt // use PREVRANDAO for unpredictable salt
                )
        }
        if (createdAddress == address(0)) {
            revert UnableToDeployCounterfactualUnwrapper();
        }

        _burn(cellophaneTokenId);
    }
}
