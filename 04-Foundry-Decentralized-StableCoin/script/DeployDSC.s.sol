// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract DeployDSC is Script {
    function run() external returns(DecentralizedStableCoin,DSCEngine){
        DSCEngine dscEngine;

        vm.startBroadcast();
        DecentralizedStableCoin dsc = new DecentralizedStableCoin();
        // DSCEngine engine = new DSCEngine(,,dsc); 
        vm.stopBroadcast();

    }
}