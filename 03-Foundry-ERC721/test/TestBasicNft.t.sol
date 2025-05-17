// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {BasicNft} from "../src/BasicNft.sol";
import {console} from "forge-std/console.sol";
import {DeployBasicNft} from "../script/DeployBasicNft.s.sol";

contract TestBasicNft is Test {
    DeployBasicNft public deployer;
    BasicNft public basicNft;

    //address
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    string public SHIBA = "https://ipfs.io/ipfs/bafybeielszifulc3qgvhd37q5cmy2veldhzyat2yerqv7gbthkg2palo2q?filename=DogNFT.json";

    function setUp() public {
        deployer = new DeployBasicNft();
        basicNft = deployer.run();
    }

    function testNameIsCorrect() external view{
        string memory expectedName = "DogNFT";
        string memory actualName = basicNft.name();

        //This is becuase it is a array of bytes so we take hash of it and then compare the hashes of both of them
        assertEq(keccak256(abi.encodePacked(expectedName)),keccak256(abi.encodePacked(actualName)));
    }

    function testSymbolIsCorrect() external view{
        string memory expectedSymbol = "DOG";
        string memory actualSymbol = basicNft.symbol();

        assertEq(keccak256(abi.encodePacked(expectedSymbol)),keccak256(abi.encodePacked(actualSymbol)));
    }

    function testTheIntialTokenCounterIsZero() external view {
        assertEq(basicNft.s_tokenCounter(),0);
    }

    function testWhenMintNftTokenCounterGetsIncremented() external {
        vm.prank(bob);
        basicNft.mintNft(SHIBA);

        assertEq(basicNft.s_tokenCounter(),1);
    }

    function testTheOwnerBalanceIncreasesWhenNftIsMinted() external {
        vm.prank(bob);
        basicNft.mintNft(SHIBA);

        assertEq(basicNft.balanceOf(bob),1);
    }

    function testTheTokenIdToTokenUriIsUpdated() external {
        vm.prank(bob);
        basicNft.mintNft(SHIBA);
        assertEq(keccak256(abi.encodePacked(basicNft.tokenURI(0))),keccak256(abi.encodePacked(SHIBA)));

        vm.prank(alice);
        basicNft.mintNft(SHIBA);
        assertEq(keccak256(abi.encodePacked(basicNft.tokenURI(1))),keccak256(abi.encodePacked(SHIBA)));
    }
}