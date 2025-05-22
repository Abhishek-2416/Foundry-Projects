// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {DynamicNft} from "../src/DynamicNFT.sol";
import {Base64} from "@openzeppelin/contracts/utils/Base64.sol";

contract DeployDynamicNft is Script {
    function run() external returns(DynamicNft){
        string memory happySvg = vm.readFile("./images/dynamicNft/HappyNFT.svg");
        string memory sadSvg = vm.readFile("./images/dynamicNft/SadNFT.svg");

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        string memory rpcUrl = vm.envString("RPC_URL");
        string memory fujiRpcUrl = vm.envString("FUJI_RPC_URL");

        vm.createSelectFork(fujiRpcUrl);

        vm.startBroadcast(privateKey);
        DynamicNft moodNft = new DynamicNft(svgToImageUri(happySvg),svgToImageUri(sadSvg));
        vm.stopBroadcast();

        return moodNft;
    }

    function svgToImageUri(string memory svg) public pure returns(string memory){
        string memory baseURL = "data:image/svg+xml;base64,";
        string memory svgBase64Encoded = Base64.encode(bytes(string(abi.encodePacked(svg))));
        return string(abi.encodePacked(baseURL, svgBase64Encoded));

    }
}