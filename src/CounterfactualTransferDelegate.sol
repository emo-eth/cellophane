// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {IERC721} from "forge-std/interfaces/IERC721.sol";

/**
 * @title  CounterfactualTransferDelegate
 * @author emo.eth
 * @notice This smart contract uses an existing token approval to transfer an ERC721 token from one address to another
 *         and then self-destruct, all within its constructor. This allows for a smart contract to delegate transfers
 *         of ERC721 tokens from a pseudorandom address that does not trigger `EXTCODESIZE` or `EXTCODEHASH` checks.
 */
contract CounterfactualTransferDelegate {
    constructor(address tokenAddress, uint256 tokenId, address from, address to) {
        // Transfer the token
        IERC721(tokenAddress).transferFrom(from, to, tokenId);

        // selfdestruct while we still can :)
        selfdestruct(payable(to));
    }
}
