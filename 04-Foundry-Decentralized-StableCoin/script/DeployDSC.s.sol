// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.20;

// import {Script} from "forge-std/Script.sol";
// import {DSCEngine} from "../src/DSCEngine.sol";
// import {HelperConfig} from "../script/HelperConfig.s.sol";
// import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

// contract DeployDSC is Script {

//     struct DeployDSCNetworkConfig {
//         address[] tokenAddresses;
//         address[] priceFeedAddress;
//         uint256 deployer;
//     }

//     function run() external returns(DecentralizedStableCoin,DSCEngine){
//         HelperConfig helperConfig = new HelperConfig();
//         // DeployDSCNetworkConfig memory cfg = helperConfig.getActiveNetworkConfig();

//         // address[] memory tokens  = cfg.tokenAddresses;
//         // address[] memory priceFeed = cfg.priceFeedAddress;
//         // uint256 deployerKey = cfg.deployer;
        

//         vm.startBroadcast(deployerKey);
//         DecentralizedStableCoin dsc = new DecentralizedStableCoin();
//         DSCEngine engine = new DSCEngine(tokens,priceFeed,address(dsc)); 
//         vm.stopBroadcast();

//         return (dsc,engine);
//     }
// }