// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vault} from "../src/Vault.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {IRebaseToken} from "../src/Interfaces/IRebaseToken.sol";
import {TokenPool} from "ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {CCIPLocalSimulatorFork,Register} from "@chainlink/local/src/ccip/CCIPLocalSimulatorFork.sol";
import {TokenAdminRegistry} from "ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/TokenAdminRegistry.sol";
import {IERC20} from "ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/interfaces/IERC20.sol";
import {RegistryModuleOwnerCustom} from "ccip/contracts/src/v0.8/ccip/tokenAdminRegistry/RegistryModuleOwnerCustom.sol";

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

    //Network details
    Register.NetworkDetails sepoliaNetworkDetails;
    Register.NetworkDetails arbNetworkDetails;

    function setUp() public {
        sepoliaFork = vm.createSelectFork("sepolia"); //Here we are creating and as well as selecting that same fork
        arbSepoliaFork = vm.createFork("arbSepoliaFork"); //Here we are not selecting that fork but just creating it

        //Now that we want to test this on local so we have something know as the Chainlink Local
        //This will help us get the Mocks and all we need for local testing
        ccipLocalSimulatorFork = new CCIPLocalSimulatorFork();

        //This will make the ccipLocalSimulatorFork address persistent across both the chains
        // Basically we can use this address on both chains in our case Sepolia and ArbSepolia
        vm.makePersistent(address(ccipLocalSimulatorFork));

        // ------------------- DEPLOY AND CONFIGURE ON SEPOLIA ------------------- //
        // Get network details for Sepolia fork (e.g., router, registry, rmn proxy)
        sepoliaNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        // Start impersonating the deployer (owner) account for Sepolia setup
        vm.startPrank(owner);

        // Deploy the rebase token on Sepolia (ERC20 with dynamic interest logic)
        sepoliaToken = new RebaseToken();

        // Deploy the Vault contract on Sepolia which allows deposits & redemptions
        vault = new Vault(IRebaseToken(address(sepoliaToken)));

        // Deploy the RebaseTokenPool (cross-chain bridge logic) on Sepolia
        sepoliaPool = new RebaseTokenPool(
            IERC20(address(sepoliaToken)),                    // Token address
            new address[](0) ,                                 // Allowlist (empty for now)
            sepoliaNetworkDetails.rmnProxyAddress,            // RMN Proxy address from CCIP config
            sepoliaNetworkDetails.routerAddress               // Router address from CCIP config
        );

        // Give Vault permission to mint/burn tokens (for user deposits/redeems)
        sepoliaToken.grantMintAndBurnRole(address(vault));

        // Give the Pool permission to mint/burn tokens (for bridging)
        sepoliaToken.grantMintAndBurnRole(address(sepoliaPool));

        // Register the RebaseToken into the CCIP registry, setting the deployer as admin
        RegistryModuleOwnerCustom(sepoliaNetworkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(sepoliaToken));

        // Accept the token admin role from CCIP registry (must be done after registration)
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(sepoliaToken));

        // Link the token with its Pool in the TokenAdminRegistry (important for bridging)
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(sepoliaToken), address(sepoliaPool));

        configureTokenPool(sepoliaFork,sepoliaPool,arbNetworkDetails.chainSelector,)

        // Stop impersonating the owner
        vm.stopPrank();


        // ------------------- DEPLOY AND CONFIGURE ON ARBITRUM SEPOLIA ------------------- //

        // Switch to the Arbitrum Sepolia fork
        vm.selectFork(arbSepoliaFork);

        // Get network details for Arbitrum Sepolia
        arbNetworkDetails = ccipLocalSimulatorFork.getNetworkDetails(block.chainid);

        // Start impersonating owner account on Arbitrum Sepolia
        vm.startPrank(owner);

        // Deploy the rebase token on Arbitrum Sepolia
        arbSepoliaToken = new RebaseToken();

        // Deploy the RebaseTokenPool on Arbitrum Sepolia
        arbSepoliaPool = new RebaseTokenPool(
            IERC20(address(arbSepoliaToken)),                 // Token address
            new address[](0),                                 // Allowlist (empty)
            arbNetworkDetails.rmnProxyAddress,                // RMN proxy from Arbitrum config
            arbNetworkDetails.routerAddress                   // Router from Arbitrum config
        );

        // Register the Arbitrum Sepolia token with CCIP registry
        RegistryModuleOwnerCustom(arbNetworkDetails.registryModuleOwnerCustomAddress)
            .registerAdminViaOwner(address(arbSepoliaToken));

        // Accept admin role for the token in CCIP registry
        TokenAdminRegistry(arbNetworkDetails.tokenAdminRegistryAddress)
            .acceptAdminRole(address(arbSepoliaToken));

        // Register the Arbitrum token's pool in the CCIP registry
        // NOTE: This uses Sepolia's registry for local simulation purposes
        TokenAdminRegistry(sepoliaNetworkDetails.tokenAdminRegistryAddress)
            .setPool(address(arbSepoliaToken), address(arbSepoliaPool));

        // Stop impersonating the owner
        vm.stopPrank();
    }

    // So this is function via which we can set the chain we want to be "cross chain " with 
    function configureTokenPool(uint256 fork,address localPool,uint64 remoteChainSelector,bool allowed,address remoteTokenAddress) public {
        vm.selectFork(fork);
        vm.prank(owner);
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePool);

        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: allowed,
            remotePoolAddress: remotePoolAddresses,
            remoteTokenAddress: remoteTokenAddress,
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false,capacity: 0,rate:0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false,capacity: 0,rate:0})
        });
        TokenPool(localPool).applyChainUpdates(new uint64[](0),chainsToAdd);
    }
}