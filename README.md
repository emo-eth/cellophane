# Cellophane

## Overview

Cellophane is a proof-of-concept counterfactual ERC721 token wrapper.

Cellophane differs from conventional token wrappers because tokens are never deposited into, or directly transferred by, the Cellophane smart contract. 

All token transfers happen within the constructors of counterfactual smart contracts in order to bypass `EXTCODESIZE` and `EXTCODEHASH` checks. Cellophane thus is particularly immune to attempts to restrict operators using a deny-list, but is still thwarted by much more restrictive [allow-list and CAPTCHA based approaches](https://github.com/transmissions11/ERC721C) (which generally break token composability).


## Usage

Cellophane implements six key methods: `deriveDepositAddress()`, `deriveDepositDelegateAddress()`, `wrap()`, `deposit()`, `depositAndWrap()`, and `unwrap()`.

Tokens are "deposited" to the address returned by `deriveDepositAddress()`. The `wrap()` method called with the same arguments checks that the token is held by the counterfactual deposit address, and then mints a representative ERC721 token to the "owner" address specified in the calculation of the deposit address. The wrapped token owner is then free to trade the new ERC721 token as they wish.

The owner of the ERC721 token may unwrap the token at any time by calling `unwrap()` with the wrapped token ID. The process can be repeated as many times as desired.

The `deposit()` and `depositAndWrap()` convenience methods use an intermediary delegate contract to safely transfer tokens to their deposit addreses. Before depositing, the owner must approve the `CounterfactualTransferDelegate` at the address returned by `deriveDepositDelegateAddress()`.

The `depositAndWrap()` method uses the delegate to deposit the token to its counterfactual deposit address and mints the corresponding Cellophone token in a single transaction.

The `deposit()` method uses the delegate to deposit the token to the counterfactual deposit address, but does not mint the corresponding wrapped Cellophane token. The wrapped token can be minted later by calling `wrap()` with the same arguments.


## Counterfactual Smart Contracts

Counterfactual smart contracts are deployed to deterministic addresses using the `CREATE2` opcode. Because `CREATE2` deploys to a deterministic address, it's possible to know the address of a smart contract before it actually exists on-chain – hence the term "counterfactual."

This means users can "deposit" tokens to a seemingly random address, knowing that Cellophane can retrieve them at a later time.

Both `CounterfactualUnwrapper` and `CounterfactualTransferDelegate` perform all operations within their constructors, before it's possible to check if code is deployed to their addresses, and then call `SELFDESTRUCT` to destroy themselves.

### CounterfactualUnwrapper

`CounterfactualUnwrapper` is the counterfactual contract that is eventually deployed to the "deposit" address calculated by the `deriveDepositAddress()` method, which transfers the underlying token to the current owner of the corresponding Cellophane token.

### CounterfactualTransferDelegate

`CounterfactualTransferDelegate` is a separate counterfactual contract responsible for moving tokens out of the deposit address and, optionally, depositing tokens.

Since Cellophane exposes enough information to determine the `CounterfactualUnwrapper` addresses once `wrap()` is called, it's technically possible to individually block transfers from those addresses (albeit inconvenient and expensive to keep up with).

When unwrapping a token, the `CounterfactualUnwrapper` deploys a `CounterfactualTransferDelegate` to a random address (by using the `PREVRANDAO` opcode as the `CREATE2` salt, which varies with each block), so it's impossible to know the eventual address of the `CounterfactualTransferDelegate` before the transaction to unwrap is submitted (though that may be front-run).

When using the the `deposit()` methods, Cellophane deploys a `CounterfactualTransferDelegate` to facilitate safe transfers to counterfactual deposit addresses. This way, Cellophane never directly transfers wrapped tokens. The `CounterfactualTransferDelegate` address (calculated by calling the `deriveDepositDelegateAddress()` methods) must be pre-approved by the token owner before the `deposit()` methods can be called, as the `CounterfactualTransferDelegate` must be approved to transfer the token.