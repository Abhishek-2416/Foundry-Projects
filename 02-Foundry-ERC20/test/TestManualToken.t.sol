// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ManualToken} from "../src/ManualToken.sol";

contract TestManualToken is Test{
    ManualToken token;

    //addresses
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    function setUp() public {
        token = new ManualToken();
    }

    function testTokenName() external view{
        string memory actualName = token.name();
        string memory expectedName = "AbhiToken";

        assertEq(keccak256(abi.encodePacked(actualName)),keccak256(abi.encodePacked(expectedName)));
    }

    function testTokenSymbol() external view{
        string memory actualSymbol = token.symbol();
        string memory expectedSymbol = "ABHI";

        assertEq(keccak256(abi.encodePacked(actualSymbol)),keccak256(abi.encodePacked(expectedSymbol)));
    }

    function testTokenDecimals() external view{
        uint8 actualDecimals = token.decimals();
        uint8 expectedDecimals = 0;

        assertEq(actualDecimals,expectedDecimals);
    }

    function testTotalSupply()external view{
        uint256 actualTokenSupply = token.totalSupply();
        uint256 expectedTokenSupply = 1000000;

        assertEq(actualTokenSupply,expectedTokenSupply);
    }

    function testTheTotalSupplyIsFounderBalance() external {
        uint256 tokenSupply = token.totalSupply();
        
        vm.startPrank(msg.sender);
        uint256 ownerBalance = token.balanceOf(address(this));
        assertEq(ownerBalance,tokenSupply);
    }

    
}