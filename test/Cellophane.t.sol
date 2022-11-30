// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {BaseTest} from "./BaseTest.t.sol";
import {Cellophane} from "../src/Cellophane.sol";

contract CellophaneTest is BaseTest {
    Cellophane test;

    function setUp() public override {
        super.setUp();
        test = new Cellophane();
    }

    function testDerive() public {
        assertEq(
            test.derive(address(testERC721), 1, address(this)),
            test.derive(address(testERC721), 1, address(this), bytes32(0))
        );
        assertFalse(
            test.derive(address(testERC721), 1, address(this))
                == test.derive(address(testERC721), 1, address(this), bytes32(uint256(1)))
        );

        assertFalse(
            test.derive(address(testERC721), 1, address(1)) == test.derive(address(testERC721), 1, address(this))
        );

        assertFalse(test.derive(address(1), 1, address(this)) == test.derive(address(testERC721), 1, address(this)));
    }

    function testWrap() public {
        address derived = test.derive(address(testERC721), 1, address(this));
        testERC721.mint(derived, 1);
        uint256 cellophaneId = test.wrap(address(testERC721), 1, address(this));
        assertEq(test.ownerOf(cellophaneId), address(this));
    }

    function testWrapWithSalt() public {
        address derived = test.derive(address(testERC721), 1, address(this), bytes32(uint256(1)));
        testERC721.mint(derived, 1);
        uint256 cellophaneId = test.wrap(address(testERC721), 1, address(this), bytes32(uint256(1)));
        assertEq(test.ownerOf(cellophaneId), address(this));
    }

    function testWrap_alreadyWrapped() public {
        address derived = test.derive(address(testERC721), 1, address(this));
        testERC721.mint(derived, 1);
        uint256 cellophaneId = test.wrap(address(testERC721), 1, address(this));
        vm.expectRevert(abi.encodeWithSelector(Cellophane.AlreadyWrapped.selector, cellophaneId));
        cellophaneId = test.wrap(address(testERC721), 1, address(this));
    }

    function testWrap_notInCounterfactualContainer() public {
        address derived = test.derive(address(testERC721), 1, address(this));
        testERC721.mint(derived, 1);
        vm.expectRevert(abi.encodeWithSelector(Cellophane.OriginalTokenNotInCounterfactualContainer.selector));
        test.wrap(address(testERC721), 1, address(this), bytes32(uint256(1)));
    }

    function testUnwrap() public {
        address derived = test.derive(address(testERC721), 1, address(this));
        testERC721.mint(derived, 1);
        uint256 cellophaneId = test.wrap(address(testERC721), 1, address(this));
        test.unwrap(cellophaneId);
        assertEq(testERC721.ownerOf(1), address(this));
    }

    function testUnwrapWithSalt() public {
        address derived = test.derive(address(testERC721), 1, address(this), bytes32(uint256(1)));
        testERC721.mint(derived, 1);
        uint256 cellophaneId = test.wrap(address(testERC721), 1, address(this), bytes32(uint256(1)));
        test.unwrap(cellophaneId);
        assertEq(testERC721.ownerOf(1), address(this));
    }

    function testUnwrap_notOwner() public {
        address derived = test.derive(address(testERC721), 1, address(this));
        testERC721.mint(derived, 1);
        uint256 cellophaneId = test.wrap(address(testERC721), 1, address(this));
        test.transferFrom(address(this), address(1), cellophaneId);
        vm.expectRevert(abi.encodeWithSelector(Cellophane.NotOwner.selector, cellophaneId));
        test.unwrap(cellophaneId);
    }

    function testUnwrap_notWrapped() public {
        address derived = test.derive(address(testERC721), 1, address(this), bytes32(uint256(1)));
        testERC721.mint(derived, 1);
        vm.expectRevert("NOT_MINTED");
        test.unwrap(uint256(keccak256(abi.encodePacked(address(testERC721), uint256(1)))));
    }
}
