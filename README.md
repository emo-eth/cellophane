# Cellophane

## Overview

Cellophane is an educational, proof-of-concept counterfactual ERC721 token wrapper.

Cellophane differs from conventional token wrappers because tokens are never deposited into, or directly transferred by, the Cellophane smart contract. 

All token transfers happen within the constructors of counterfactual smart contracts, so, given the constraints of the EVM at the time of writing, it is impossible to detect that a token is being handled by a smart contract at all (without requiring a [CAPTCHA for transfers](https://github.com/transmissions11/ERC721C)). 


## Usage

Cellophane implements three key methods: `derive()`, `wrap()`, and `unwrap()`.

Tokens are "deposited" to the address returned by `derive()`. The `wrap()` method called with the same arguments checks that the token is held by the counterfactual address, and then mints a representative ERC721 token to the "owner" address specified in the calculation of the counterfactual address. The owner is then free to trade the new ERC721 token as they wish.

The owner of the ERC721 token may unwrap the token at any time by calling `unwrap()` with the wrapped token ID. The process can be repeated as many times as desired.

***TODO: Add a counterfactual deposit delegate for safely depositing tokens to derived counterfactual addresses.***

## Counterfactual Smart Contracts

Counterfactual smart contracts are deployed to deterministic addresses using the `CREATE2` opcode. Because `CREATE2` deploys to a deterministic address, it's possible to know the address of a smart contract before it actually exists on-chain – hence the term "counterfactual."

This means users can "deposit" tokens to a seemingly random address, knowing that Cellophane can retrieve them at a later time.

Both `CounterfactualUnwrapper` and `CounterfactualDelegate` perform all operations within their constructors, before it's possible to check if code is deployed to their addresses, and then call `SELFDESTRUCT` to destroy themselves.

### CounterfactualUnwrapper

`CounterfactualUnwrapper` is the counterfactual contract that is eventually deployed to the "deposit" address calculated by the `derive()` method.

### CounterfactualDelegate

`CounterfactualDelegate` is a separate counterfactual contract deployed by the `CounterfactualUnwrapper`, and is responsible for moving the token out of the deposit address.

Since Cellophane exposes enough information to determine the `CounterfactualUnwrapper` addresses once `wrap()` is called, it's technically possible to individually block transfers from those addresses (albeit inconvenient and expensive to keep up with).

The `CounterfactualDelegate` is deployed to a random address (by using the `PREVRANDAO` opcode as the `CREATE2` salt, which varies with each block), so it's impossible to know the eventual address of the `CounterfactualDelegate` before it's deployed.
