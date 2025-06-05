// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract DeployDSC is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    function run() external returns(DecentralizedStableCoin,DSCEngine){
        string memory ANVIL_RPC_URL = vm.envString("ANVIL_RPC_URL");

        HelperConfig helperConfig = new HelperConfig();
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) = helperConfig.activeNetworkConfig();

        //I think this is how we update arrays and not like how we do simply push
        tokenAddresses = [weth,wbtc];
        priceFeedAddresses = [wethUsdPriceFeed,wbtcUsdPriceFeed];

        vm.createSelectFork(ANVIL_RPC_URL);

        vm.startBroadcast(deployerKey);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine engine = new DSCEngine(tokenAddresses,priceFeedAddresses,address(dsc)); 
        vm.stopBroadcast();

        return (dsc,engine);
    }
}