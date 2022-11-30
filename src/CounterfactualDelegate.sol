// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC721} from "forge-std/interfaces/IERC721.sol";

contract CounterfactualDelegate {
    constructor(address tokenAddress, uint256 tokenId, address from, address to) {
        // Transfer the token from the CounterfactualUnwrapper to the owner of the Cellophane wrapped token
        IERC721(tokenAddress).transferFrom(from, to, tokenId);

        // selfdestruct while we still can :)
        selfdestruct(payable(0));
    }
}
