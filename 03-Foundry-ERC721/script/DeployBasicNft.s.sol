// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {BasicNft} from "../src/BasicNft.sol";

contract DeployBasicNft is Script {
    BasicNft basicNft;

    function run() external returns(BasicNft) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        string memory rpcUrl = vm.envString("RPC_URL");

        vm.createSelectFork(rpcUrl);

        vm.startBroadcast(privateKey);
        basicNft = new BasicNft();
        vm.stopBroadcast();
        return basicNft;
    }
}