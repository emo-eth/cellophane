// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {ERC721} from "solmate/tokens/ERC721.sol";

contract TestERC721 is ERC721("Test", "TEST") {
    function tokenURI(uint256) public pure override returns (string memory) {
        return "https://cellophane.art";
    }

    function mint(address to, uint256 tokenId) public {
        _mint(to, tokenId);
    }

    function burn(uint256 tokenId) public {
        _burn(tokenId);
    }
}
