// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ManualToken} from "../src/ManualToken.sol";

contract TestManualToken is Test {
    ManualToken token;

    //addresses
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    //events
    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);

    uint256 public constant STARTING_BALANCE = 100 ether;
    uint256 public constant TOTAL_SUPPLY = 1000 ether;

    function setUp() external {
        token = new ManualToken();
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

    //Transfer Function

    function testTheBalanceShouldBeGreaterThanAmountTransfered() external {
        vm.expectRevert();
        token.transfer(bob, STARTING_BALANCE + TOTAL_SUPPLY);
    }

    function testNumberOfTokensToBeTransfferedMustBeGreaterThanZero() external {
        vm.expectRevert();
        token.transfer(bob,0);
    }

    function testTheReceiverBalanceIncreasesAfterTransfer() external {
        assertEq(token.balanceOf(bob),0);
        token.transfer(bob,STARTING_BALANCE);
        assertEq(token.balanceOf(bob),STARTING_BALANCE);
    }

    function testTheOwnerBalanceReducesAfterTransfer() external {
        assertEq(token.balanceOf(address(this)),TOTAL_SUPPLY);
        token.transfer(bob,STARTING_BALANCE);
        assertEq(token.balanceOf(address(this)),TOTAL_SUPPLY - STARTING_BALANCE);
    }

    function testTheTransferEventIsEmittedOnTransfer() external {
        vm.expectEmit();
        emit Transfer(address(this),bob,STARTING_BALANCE);
        token.transfer(bob,STARTING_BALANCE);
    }

    // Approve
    function testTheOwnerBalanceShallBeLessThanTokensApproved() external {
        token.transfer(bob,STARTING_BALANCE);

        vm.expectRevert();
        token.approve(alice,TOTAL_SUPPLY);
    }

    function testTheTokensApprovedShallBeGreaterThanZero() external {
        token.transfer(bob,STARTING_BALANCE);

        vm.expectRevert();
        token.approve(alice,0);
    }

    function testTheAllowedMappingIsUpdates() external {
        token.transfer(bob,STARTING_BALANCE);

        vm.prank(bob);
        token.approve(alice,1 ether);
        assertEq(token.allowance(bob,alice),1 ether);
    }

    function testAnApprovalEmitWhenAllowedIsCalled() external {
        token.transfer(bob,STARTING_BALANCE);

        vm.prank(bob);
        vm.expectEmit();

        emit Approval(bob,alice,1 ether);
        token.approve(alice,1 ether);
    }

    //Transfer From
    function testTheTransferFromFunctionFailsWhenAllowedTokenIsInsufficent() external {
        token.transfer(bob,STARTING_BALANCE);

        vm.prank(bob);
        token.approve(alice,1 ether);

        vm.prank(alice);
        vm.expectRevert();
        token.transferFrom(bob,alice,2 ether);
    }

    function testTheTransferFromFunctionFailsWhenOwnerBalanceIslessThanTokensRequested() external {
        token.transfer(bob,STARTING_BALANCE);

        vm.prank(bob);
        token.approve(alice, STARTING_BALANCE);

        vm.prank(alice);
        vm.expectRevert();
        token.transferFrom(bob,alice,TOTAL_SUPPLY);
    }

    function testTheAllowersBalancesChangesWhenTransferedFrom() external {
        token.transfer(bob,STARTING_BALANCE);

        vm.prank(bob);
        token.approve(alice, 1 ether);

        vm.prank(alice);
        token.transferFrom(bob,alice, 1 ether);
        assertEq(token.balanceOf(bob),STARTING_BALANCE - 1 ether);
    }

    function testTheAllowedBalanceChangesForTheRequester() external {
        token.transfer(bob,STARTING_BALANCE);

        vm.prank(bob);
        token.approve(alice, 1 ether);

        vm.prank(alice);
        token.transferFrom(bob,alice, 1 ether);
        assertEq(token.allowance(bob,alice),0);
    }

    function testTheRequesterBalanceHasIncreased() external {
        token.transfer(bob,STARTING_BALANCE);

        vm.prank(bob);
        token.approve(alice,1 ether);

        vm.prank(alice);
        token.transferFrom(bob,alice,1 ether);
        assertEq(token.balanceOf(alice), 1 ether);
    }

    function testTheTransferfunctionEmitsTransferFunction() external {
        token.transfer(bob,STARTING_BALANCE);

        vm.prank(bob);
        token.approve(alice, 1 ether);

        vm.prank(alice);
        vm.expectEmit();

        emit Transfer(bob,alice, 1 ether);

        token.transferFrom(bob,alice,1 ether);
    }

    function testTheTransferFromFunctionReturnsBooleanValue() external {
        token.transfer(bob,STARTING_BALANCE);

        vm.prank(bob);
        token.approve(alice, 1 ether);

        vm.prank(alice);
        (bool success) = token.transferFrom(bob,alice,1 ether);
        assertEq(success,true);
    }
}