// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {BaseTest} from "./BaseTest.t.sol";
import {CounterfactualUnwrapper} from "../src/CounterfactualUnwrapper.sol";

contract CounterfactualUnwrapperTest is BaseTest {
    function setUp() public override {
        super.setUp();
        testERC721.mint(0x2e234DAe75C793f67A35089C9d99245E1C58470b, 1);
        new CounterfactualUnwrapper(address(testERC721), 1, 1);
        assertEq(testERC721.ownerOf(1), address(this));
        testERC721.burn(1);
    }

    function testAtomicDeploy() public {
        testERC721.mint(0xF62849F9A0B5Bf2913b396098F7c7019b51A820a, 1);
        testERC721.mint(0x5991A2dF15A8F6A256D3Ec51E99254Cd3fb576A9, 2);

        CounterfactualUnwrapper test = new CounterfactualUnwrapper(address(testERC721), 1, 1);
        assertEq(testERC721.ownerOf(1), address(this));
        test = new CounterfactualUnwrapper(address(testERC721), 2, 1);
        assertEq(testERC721.ownerOf(2), address(this));
    }

    function testSelfDestruct() public {
        assertEq(0x2e234DAe75C793f67A35089C9d99245E1C58470b.code.length, 0);
    }

    function ownerOf(uint256) public view returns (address) {
        return address(this);
    }
}
