// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Test} from "forge-std/Test.sol";
import {TestERC721} from "./helpers/TestERC721.sol";

contract BaseTest is Test {
    TestERC721 testERC721;

    function setUp() public virtual {
        testERC721 = new TestERC721();
    }
}
