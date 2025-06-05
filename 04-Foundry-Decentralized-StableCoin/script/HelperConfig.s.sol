// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";

contract HelperConfig is Script {
    
    struct NetworkConfig {
        address weth;
        address wbtc;
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        uint256 deployer;
    }

    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    int256 public constant BTC_USD_PRICE = 10000e8;
    NetworkConfig public activeNetworkConfig;

    constructor() {
        if(block.chainid == 43113){
            //Fuji Testnet
            activeNetworkConfig = getFujiConfig();
        }else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getFujiConfig() public view returns(NetworkConfig memory fujiNetworkConfig){
        address _wethUsdPriceFeed = 0x86d67c3D38D2bCeE722E601025C25a575021c6EA;
        address _wbtcUsdPriceFeed = 0x31CF013A08c6Ac228C94551d535d5BAfE19c602a;

        address _weth = 0x9668f5f55f2712Dd2dfa316256609b516292D554;
        address _wbtc = 0x5d870A421650C4f39aE3f5eCB10cBEEd36e6dF50;
        
        fujiNetworkConfig = NetworkConfig({
            weth: _weth,
            wbtc: _wbtc,
            wethUsdPriceFeed: _wethUsdPriceFeed,
            wbtcUsdPriceFeed: _wbtcUsdPriceFeed,
            deployer: vm.envUint("FUJI_PRIVATE_KEY")
        });

        return fujiNetworkConfig;
    }

    function getOrCreateAnvilConfig() public returns(NetworkConfig memory anvilNetworkConfig){
        if(activeNetworkConfig.wethUsdPriceFeed != address(0)){
            return activeNetworkConfig;
        }

        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS,ETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock("Wrapped Ethereum","WETH",msg.sender,1000e8);

        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS,BTC_USD_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock("Wrapped Bitcoin","WBTC",msg.sender,1000e8);
        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            wethUsdPriceFeed: address(ethUsdPriceFeed),
            wbtcUsdPriceFeed: address(btcUsdPriceFeed),
            deployer: vm.envUint("ANVIL_PRIVATE_KEY")
        });

        return anvilNetworkConfig;
    }

    function getActiveNetworkConfig() public view returns(NetworkConfig memory){
        return activeNetworkConfig;
    }

}