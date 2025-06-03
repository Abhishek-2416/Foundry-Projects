// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";
import {DeployDecentralizedStableCoin} from "../../script/DeployDecentralizedStableCoin.s.sol";

contract TestDecentralizedStabelCoin is Test {
    DeployDecentralizedStableCoin public deployer;
    DecentralizedStableCoin public stableCoin;

    //addresses
    uint256 anvilPrivateKey = vm.envUint("ANVIL_PRIVATE_KEY");
    address Owner = vm.addr(anvilPrivateKey);

    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    //variables
    uint256 MINT_AMOUNT = 100 ether;
    uint256 BURN_AMOUNT = 1 ether;

    function setUp() external {
        deployer = new DeployDecentralizedStableCoin();
        stableCoin = deployer.run();
    }

    function testTheContractNameIsCorrect() external view{
        string memory expectedName = "DecentralizedStableCoin";
        string memory actualName = stableCoin.name();

        assertEq(keccak256(abi.encodePacked(expectedName)),keccak256(abi.encodePacked(actualName)));
    }

    function testTheContractSymbolIsCorrect() external view{
        string memory expectedSymbol = "DSC";
        string memory actualSymbol = stableCoin.symbol();

        assertEq(keccak256(abi.encodePacked(expectedSymbol)),keccak256(abi.encodePacked(actualSymbol)));
    }

    //Mint
    function testCannotMintTokenForNullAddress() external {
        vm.prank(Owner);
        vm.expectRevert();
        stableCoin.mint(address(0), MINT_AMOUNT);
    }

    function testCannotMintTokenForNullAmount() external {
        vm.prank(Owner);
        vm.expectRevert();
        stableCoin.mint(bob,0);
    }

    function testBalanceIncreasesWhenMintedTokens() external {
        assertEq(stableCoin.balanceOf(bob),0);

        vm.prank(Owner);
        stableCoin.mint(bob,MINT_AMOUNT);

        assertEq(stableCoin.balanceOf(bob),MINT_AMOUNT);
    }

    function testMintReturnsBooleanOnCorrectExecution() external {
        vm.prank(Owner);
        bool success = stableCoin.mint(bob,MINT_AMOUNT);

        assertEq(success,true);
    }

    //Burn 
    function testCannotBurnAmountLessThanEqualToZero() external {
        vm.prank(Owner);
        stableCoin.mint(bob,MINT_AMOUNT);

        vm.prank(Owner);
        vm.expectRevert();
        stableCoin.burnFrom(bob,0);
    }

    function testCannotBurnMoreThanTheBalance() external {
        vm.prank(Owner);
        stableCoin.mint(bob,MINT_AMOUNT);

        vm.prank(Owner);
        vm.expectRevert();
        stableCoin.burnFrom(bob, MINT_AMOUNT + BURN_AMOUNT);
    }

    function testTheOwnerBalanceDecreasesWhenTokensBurnt() external {
        vm.prank(Owner);
        stableCoin.mint(bob,MINT_AMOUNT);

        vm.prank(Owner);
        stableCoin.burnFrom(bob, BURN_AMOUNT);

        assertEq(stableCoin.balanceOf(bob), MINT_AMOUNT - BURN_AMOUNT);
    }
}