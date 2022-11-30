// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {CounterfactualDelegate} from "./CounterfactualDelegate.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";

contract CounterfactualUnwrapper {
    error FailedToDeployToAddress(address expected, address actual);

    // store immutable reference to deploying contract
    address immutable CELLOPHANE;

    constructor(address tokenAddress, uint256 tokenId, uint256 cellophaneTokenId) {
        CELLOPHANE = msg.sender;
        _unwrap(msg.sender, tokenAddress, tokenId, cellophaneTokenId);
    }

    /**
     * @dev in case SELFDESTRUCT gets removed and someone tries to re-use a salt
     */
    function unwrap(address tokenAddress, uint256 tokenId, uint256 cellophaneTokenId) external {
        _unwrap(CELLOPHANE, tokenAddress, tokenId, cellophaneTokenId);
    }

    function _unwrap(address cellophane, address tokenAddress, uint256 tokenId, uint256 cellophaneTokenId) private {
        // get the owner of the representative token
        address currentOwner = IERC721(cellophane).ownerOf(cellophaneTokenId);
        // calculate initcode
        bytes memory initCode = abi.encodePacked(
            type(CounterfactualDelegate).creationCode, abi.encode(tokenAddress, tokenId, address(this), currentOwner)
        );
        bytes32 initCodeHash = keccak256(initCode);
        address delegateAddress = address(
            uint160( // downcast to match the address type.
                uint256( // convert to uint to truncate upper digits.
                    keccak256( // compute the CREATE2 hash using 4 inputs.
                        abi.encodePacked( // pack all inputs to the hash together.
                            hex"ff", // start with 0xff to distinguish from RLP.
                            address(this), // this contract will be the caller.
                            block.difficulty, // use PREVRANDAO for unpredictable salt
                            initCodeHash // pass in the hash of initialization code.
                        )
                    )
                )
            )
        );

        // approve counterfactual delegate to transfer tokens on behalf of the CounterfactualUnwrapper
        IERC721(tokenAddress).setApprovalForAll(delegateAddress, true);

        // using inline assembly: load data and length of data, then call CREATE2.
        address actualDeploymentAddress;
        /// @solidity memory-safe-assembly
        assembly {
            let encoded_data := add(0x20, initCode) // load initialization code.
            let encoded_size := mload(initCode) // load the init code's length.
            actualDeploymentAddress :=
                create2( // call CREATE2 with 4 arguments.
                    0, // forward no value
                    encoded_data, // pass in initialization code.
                    encoded_size, // pass in init code's length.
                    difficulty() // use PREVRANDAO for unpredictable salt
                )
        }

        // ensure that the delegate was deployed to the expected address
        if (actualDeploymentAddress != delegateAddress) {
            revert FailedToDeployToAddress(delegateAddress, actualDeploymentAddress);
        }

        // selfdestruct while we still can :)
        selfdestruct(payable(0));
    }
}
