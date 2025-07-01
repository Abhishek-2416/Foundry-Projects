// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vault} from "../src/Vault.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {RebaseTokenPool} from "../src/RebaseTokenPool.sol";
import {IRebaseToken} from "../src/Interfaces/IRebaseToken.sol";
import {Client} from "ccip/contracts/src/v0.8/ccip/libraries/Client.sol";
import {TokenPool} from "ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {RateLimiter} from "ccip/contracts/src/v0.8/ccip/libraries/RateLimiter.sol";
import {IRouterClient} from "ccip/contracts/src/v0.8/ccip/interfaces/IRouterClient.sol";
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

    uint256 SEND_VALUE = 1e5;

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

        configureTokenPool(sepoliaFork,address(sepoliaPool),sepoliaNetworkDetails.chainSelector,true,address(arbSepoliaPool),address(arbSepoliaToken));

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

        configureTokenPool(arbSepoliaFork,address(arbSepoliaPool),arbNetworkDetails.chainSelector,true,address(sepoliaPool),address(sepoliaToken));

        // Stop impersonating the owner
        vm.stopPrank();
    }

    // So this is function via which we can set the chain we want to be "cross chain " with 
    function configureTokenPool(uint256 fork,address localPool,uint64 remoteChainSelector,bool allowed,address remotePool,address remoteTokenAddress) public {
        vm.selectFork(fork);
        vm.prank(owner);
        bytes[] memory remotePoolAddresses = new bytes[](1);
        remotePoolAddresses[0] = abi.encode(remotePool);

        TokenPool.ChainUpdate[] memory chainsToAdd = new TokenPool.ChainUpdate[](1);
        chainsToAdd[0] = TokenPool.ChainUpdate({
            remoteChainSelector: remoteChainSelector,
            allowed: allowed,
            remotePoolAddress: abi.encode(remotePool),
            remoteTokenAddress: abi.encode(remoteTokenAddress),
            outboundRateLimiterConfig: RateLimiter.Config({isEnabled: false,capacity: 0,rate:0}),
            inboundRateLimiterConfig: RateLimiter.Config({isEnabled: false,capacity: 0,rate:0})
        });
        TokenPool(localPool).applyChainUpdates(chainsToAdd);
    }

    function bridgeTokens(uint256 amountToBridge,uint256 localFork, uint256 remoteFork,Register.NetworkDetails memory localNetworkDetails,Register.NetworkDetails memory remoteNetworkDetails,RebaseToken localToken,RebaseToken remoteToken) public {
        vm.selectFork(localFork);
        Client.EVMTokenAmount[] memory tokenAmounts = new Client.EVMTokenAmount[](1);
        tokenAmounts[0] = Client.EVMTokenAmount({
            token: address(localToken),
            amount: amountToBridge
        });
        //Before getting the fees we need to get the message we need to send cross chain
        Client.EVM2AnyMessage memory message = Client.EVM2AnyMessage({
            receiver: abi.encode(bob), // Assuming that the user is sending data to itself only the other chain
            data: "",
            tokenAmounts: tokenAmounts,
            feeToken: localNetworkDetails.linkAddress,
            extraArgs: Client._argsToBytes(Client.EVMExtraArgsV1({gasLimit: 0}))
        });

        //Now we get the fees
        uint256 fee = IRouterClient(localNetworkDetails.routerAddress).getFee(remoteNetworkDetails.chainSelector,message);

        //Pretend that we get some link
        ccipLocalSimulatorFork.requestLinkFromFaucet(bob,fee);

        //Approve Router contract for fee
        vm.prank(bob);
        IERC20(localNetworkDetails.linkAddress).approve(localNetworkDetails.routerAddress,fee);

        //Aprove Router to allow to spend, so we can send tokens 
        vm.prank(bob);
        IERC20(address(localToken)).approve(localNetworkDetails.routerAddress,amountToBridge);

        uint256 localBalanceBefore = localToken.balanceOf(bob);

        //Now we send tokens cross chain
        vm.prank(bob);
        IRouterClient(localNetworkDetails.routerAddress).ccipSend(remoteNetworkDetails.chainSelector,message);
        
        uint256 localBalanceAfter = localToken.balanceOf(bob);
        assertEq(localBalanceAfter,localBalanceBefore - amountToBridge);

        //Now to check if the message has proporgated cross chain
        vm.selectFork(remoteFork);
        vm.warp(block.timestamp + 1 hours);
        uint256 remoteBalanceBefore = remoteToken.balanceOf(bob);

        //Sending the token to the remote chain
        ccipLocalSimulatorFork.switchChainAndRouteMessage(remoteFork);

        //Getting balance after
        uint256 remoteBalanceAfter = remoteToken.balanceOf(bob);

        assertEq(remoteBalanceBefore + amountToBridge, remoteBalanceAfter);

        // Now we check the interest rate of this user on this chain is same to as the source chain
        assertEq(remoteToken.getUserInterestRate(bob),localToken.getUserInterestRate(bob));
    }

    function testBridgeAllTokens() public{
        vm.selectFork(sepoliaFork);
        vm.deal(bob,SEND_VALUE);

        // User will deposit into the vault
        vm.prank(bob);
        Vault(payable(address(vault))).deposit{value: SEND_VALUE}();
        assertEq(sepoliaToken.balanceOf(bob),SEND_VALUE);

        //Now we bridge tokens
        bridgeTokens(SEND_VALUE,sepoliaFork,arbSepoliaFork,sepoliaNetworkDetails,arbNetworkDetails,sepoliaToken,arbSepoliaToken);

        assertEq(arbSepoliaToken.balanceOf(bob),SEND_VALUE);
    }
}