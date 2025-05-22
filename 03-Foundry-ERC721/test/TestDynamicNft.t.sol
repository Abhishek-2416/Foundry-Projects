// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DynamicNft} from "../src/DynamicNFT.sol";
import {DeployDynamicNft} from "../script/DeployDynamicNft.s.sol";

contract TestDynamicNft is Test{
    DynamicNft public moodNft;
    DeployDynamicNft public deployer;

    //variables
    enum Mood {
        HAPPY,
        SAD
    }

    //Addresses
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    function setUp() external {
        deployer = new DeployDynamicNft();
        moodNft = deployer.run();
    }

    function testTheNameOfTheNftIsCorrect() external {
        string memory expectedName = "MoodNFT";
        string memory actualName = moodNft.name();

        assertEq(keccak256(abi.encodePacked(expectedName)),keccak256(abi.encodePacked(actualName)));
    }

    function testTheNftSymbolIsCorrect() external {
        string memory expectedSymbol = "MN";
        string memory actualSymbol = moodNft.symbol();

        assertEq(keccak256(abi.encodePacked(expectedSymbol)),keccak256(abi.encodePacked(actualSymbol)));
    }
    
    //Mint NFT
    function testCanMintNftAndOwnerBalanceIncreases() external {
        assertEq(moodNft.balanceOf(bob),0);

        vm.prank(bob);
        moodNft.mintNft();

        assertEq(moodNft.balanceOf(bob),1);
    }

    function testWhenNftMintsItIsDefaultToHappy() external {
        vm.prank(bob);
        moodNft.mintNft();

        //Enum is technically uint just under the hood so values like 0 and 1 maybe
        assertEq(uint(moodNft.getTokenIdToMood(0)), uint(Mood.HAPPY));
    }

    function testTheTokenCounterIncreasesWhenNftMinted() external {
        assertEq(moodNft.s_tokenCounter(),0);

        vm.prank(bob);
        moodNft.mintNft();

        assertEq(moodNft.s_tokenCounter(),1);
    }

    //Flip Mood

    function testFlipMood() external{
        vm.prank(bob);
        moodNft.mintNft();

        vm.prank(bob);
        moodNft.flipMood(0);
    }

    function testFlipMoodShallBeCalledByOwnerOfNftOnly() external {
        vm.prank(bob);
        moodNft.mintNft();

        vm.prank(alice);
        vm.expectRevert();
        moodNft.flipMood(0);
    }


    function testFlipMoodExecutesProperly() external {
        vm.prank(bob);
        moodNft.mintNft();

        assertEq(uint(moodNft.getTokenIdToMood(0)), uint(Mood.HAPPY));

        vm.prank(bob);
        moodNft.flipMood(0);

        assertEq(uint(moodNft.getTokenIdToMood(0)), uint(Mood.SAD));
    }

    

}
