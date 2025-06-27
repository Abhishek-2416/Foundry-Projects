// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vault} from "../src/Vault.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {IRebaseToken} from "../src/Interfaces/IRebaseToken.sol";
import {CCIPLocalSimulatorFork} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";

contract crossChainTest is Test{
    //Forks
    uint256 sepoliaFork;
    uint256 arbSepoliaFork;

    //CCIP Local
    CCIPLocalSimulatorFork ccipLocalSimulatorFork;

    //Tokens 
    RebaseToken sepoliaToken;
    RebaseToken arbSepoliaToken;    

    //Addresses
    address owner = makeAddr("owner");
    address bob = makeAddr("bob");

    //Vault
    Vault vault;

    //RebaseTokenPool
    RebaseTokenPool sepoliaPool;
    RebaseTokenPool arbSepoliaPool;

    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia"); //Here we are creating and as well as selecting that same fork
        arbSepoliaFork = vm.createFork("arbSepoliaFork"); //Here we are not selecting that fork but just creating it

        //Now that we want to test this on local so we have something know as the Chainlink Local
        //This will help us get the Mocks and all we need for local testing
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();

        //This will make the ccipLocalSimulatorFork address persistent across both the chains
        // Basically we can use this address on both chains in our case Sepolia and ArbSepolia
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // Deploy and configure on Sepolia 
        vm.startPrank(owner);
        sepoliaToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(sepoliaToken))); 
        // sepoliaPool = new RebaseTokenPool 
        vm.stopPrank();

        // Deploy and configure on Arbitrum Sepolia 
        vm.selectFork(arbSepoliaFork);
        vm.startPrank(owner);
        arbSepoliaToken = new RebaseToken();
        vm.stopPrank();
    }
}