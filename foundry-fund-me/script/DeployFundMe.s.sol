// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {FundMe} from "../src/FundMe.sol";

contract DeployFundMe is Script {
    function run() external {
        //Loading the RPC URL and the Private Key from the .env into the Deploy
        string memory rpcURL = vm.envString("SEPOLIA_RPC_URL");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        //Creating a fork of the network (for dry-run scripting)
        vm.createSelectFork(rpcURL);

        //Here we broadcast the message using the private key
        vm.startBroadcast(privateKey);
        address priceFeed = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;
        new FundMe(priceFeed);
        vm.stopBroadcast();
    }
}