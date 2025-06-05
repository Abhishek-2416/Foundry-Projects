// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract OpenInvariantTests is StdInvariant {
    DSCEngine public engine;
    DecentralizedStableCoin public dsc;

    ERC20Mock public weth;
    ERC20Mock public wbtc;

    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;

    address[] public tokens;
    address[] public priceFeeds;

    //address
    address public bob = address(1);

    function setUp() public {
        //Deploying the mocks
        weth = new ERC20Mock("Wrapped Ether","WETH",msg.sender,1000e18);
        wbtc = new ERC20Mock("Wrapped Bitcoin","WBTC",msg.sender,1000e18);

        //Deploying the priceFeeds
        ethUsdPriceFeed = new MockV3Aggregator(8,2000e8); //$2000
        btcUsdPriceFeed = new MockV3Aggregator(8,30000e8); //$30,000

        //Deploying the DSC
        dsc = new DecentralizedStableCoin();

        //Preparing arrays
        tokens.push(address(weth));
        tokens.push(address(wbtc));
        priceFeeds.push(address(ethUsdPriceFeed));
        priceFeeds.push(address(btcUsdPriceFeed));

        //Deploy DSC Engine
        engine = new DSCEngine(tokens,priceFeeds,address(dsc));

        //Target function for fuzzing
        targetContract(address(engine));
    }

    function invariant_CollateralValueIsGreaterThanDscMinted() public view  {
        uint256 collateralValue = engine.getAccountCollateralValueInUsd(bob);
        uint256 dscMinted = engine.getDSCMinted(bob);

        console.log("Collateral USD:", collateralValue);
        console.log("DSC Minted:", dscMinted);

        assert(collateralValue >= dscMinted);
    }
}


/**
 * Okay this OpenInvariant Part of the test will fail according to me as our contract has modifiers
 */