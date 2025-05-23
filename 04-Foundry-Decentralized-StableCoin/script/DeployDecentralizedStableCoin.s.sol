// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract DeployDecentralizedStableCoin is Script {
    function run() external returns(DecentralizedStableCoin){
        string memory anvilRpc = vm.envString("ANVIL_RPC_URL");
        uint256 anvilPrivateKey = vm.envUint("ANVIL_PRIVATE_KEY");

        vm.createSelectFork(anvilRpc);

        vm.startBroadcast(anvilPrivateKey);
        DecentralizedStableCoin stableCoin = new DecentralizedStableCoin();
        vm.stopBroadcast();

        return stableCoin;
    }
}