// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ManualToken} from "../src/ManualToken.sol";

contract DeployManualToken is Script{
    function run() external{
        string memory rpcUrl = vm.envString("RPC_URL");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(privateKey);
        new ManualToken();
        vm.stopBroadcast();
    }
}