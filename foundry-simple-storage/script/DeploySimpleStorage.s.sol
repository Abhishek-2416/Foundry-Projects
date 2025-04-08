// SPDX-License-Identifier: MIT

pragma solidity ^0.8.19;

//We know that one way to deploy smart contracts was by doing it from the command line that was by using the "forge create contractName --rpc-url http://asd --private-key asdnhajshd"
//The other way of doing the same is by writing this script, which is used to deploy the contracts to the local/any blockchain

import {Script} from "forge-std/Script.sol";
import {SimpleStorage} from "../src/SimpleStorage.sol";

contract DeploySimpleStorage is Script{
    function run() external returns(SimpleStorage){
        vm.startBroadcast(); //It is a special keyword from the Script, this basically says eveything after this line we should send to the rpc
        SimpleStorage simpleStorage = new SimpleStorage(); //This creates a transcation to create a new simpleStorage contract
        vm.stopBroadcast(); //Here it is to stop the broadcast, anything within this will go to the RPC

        return simpleStorage;
    }
}