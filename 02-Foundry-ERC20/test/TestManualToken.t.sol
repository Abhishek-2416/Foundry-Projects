// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ManualToken} from "../src/ManualToken.sol";

contract TestManualToken is Test {
    ManualToken token;

    //addresses
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    uint256 public constant STARTING_BALANCE = 100 ether;

    function setUp() external {
        token = new ManualToken();
        
        token.transfer(bob,STARTING_BALANCE);
    }

    function testTokenNameIsCorrect() external view {
        string memory actualName = token.name();
        string memory expectedName = "AbhiToken";

        assertEq(keccak256(abi.encodePacked(actualName)),keccak256(abi.encodePacked(expectedName)));
    }

    function testTokenSymbolIsCorrect() external view {
        string memory actualSymbol = token.symbol();
        string memory expectedSymbol = "ABHI";

        assertEq(keccak256(abi.encodePacked(actualSymbol)),keccak256(abi.encodePacked(expectedSymbol)));
    }

    function testTheNumberOfDecimals() external view {
        uint256 actualNumberOfDecimals = token.decimals();
        uint256 expectedNumberOfDecimals = 18;

        assertEq(actualNumberOfDecimals,expectedNumberOfDecimals);
    }

    function testTheFounderBalanceIsTheTotalSupply() external view {
        uint256 ownerBalance = token.balanceOf(address(this));
        uint256 totalSupply = token.totalSupply();

        assertEq(ownerBalance,totalSupply);
    }

    function testRevertIfTransferAmountIsGreaterThanBalance() external {
        vm.prank(bob);
        token.transfer(alice, 1000 ether);
    }
}