// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract DeployDSCEngine is Script {
    address[] public tokenAddresses;
    address[] public priceFeedAddress;

    function run() external returns(DecentralizedStableCoin,DSCEngine,HelperConfig){
        HelperConfig config = new HelperConfig();
        (address weth,address wbtc,address wethUsdPriceFeed,address wbtcPriceFeed,uint256 deployerKey) = config.activeNetworkConfig();

        //This is how we add addresses into the address[]
        tokenAddresses = [weth,wbtc];
        priceFeedAddress = [wethUsdPriceFeed,wbtcPriceFeed];

        vm.startBroadcast(deployerKey);
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        DSCEngine engine = new DSCEngine(tokenAddresses,priceFeedAddress,address(dsc));
        dsc.transferOwnership(address(engine));
        vm.stopBroadcast();

        return (dsc,engine,config);
    }
}