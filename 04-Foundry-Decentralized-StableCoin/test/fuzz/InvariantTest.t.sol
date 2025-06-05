// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Invariant Fuzz testing 
 * @author Abhishek Alimchandani
 * @notice So here we are writing the Handler based Invariant Fuzz tesing for our DSC Engines
 * 
 * Invariant fuzz testing checks whether certain conditions (called invariants) always hold true — no matter what sequence of function calls are made or what inputs are given.
 * 💡 Think of invariants as the "laws" of your protocol — they must never be broken.
 */

import {Test} from "forge-std/Test.sol";
import {Handler} from "./Handler.t.sol";
import {console} from "forge-std/console.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract InvariantTest is StdInvariant,Test {
    DSCEngine public engine;
    DecentralizedStableCoin public dsc;
    Handler public handler;

    //Creating Mocks
    ERC20Mock public weth;
    ERC20Mock public wbtc;

    MockV3Aggregator public ethUsdPriceFeed;
    MockV3Aggregator public btcUsdPriceFeed;

    function setUp() external {
        //Deploying the mocks
        weth = new ERC20Mock("Wrapped Ether","WETH",msg.sender,1000e18);
        wbtc = new ERC20Mock("Wrapped Bitcoin","WBTC",msg.sender,1000e18);

        //Deploying the priceFeeds
        ethUsdPriceFeed = new MockV3Aggregator(8,2000e8); //$2000
        btcUsdPriceFeed = new MockV3Aggregator(8,30000e8); //$30,000

        //Deploying the DSC
        dsc = new DecentralizedStableCoin();

        address[] memory tokens = new address[](2);
        address[] memory priceFeeds = new address[](2);

        tokens[0] = address(weth);
        tokens[1] = address(wbtc);
        priceFeeds[0] = address(ethUsdPriceFeed);
        priceFeeds[1] = address(btcUsdPriceFeed);


        //Deploying the DSC Engine
        engine = new DSCEngine(tokens,priceFeeds,address(dsc));

        //Deploy the handler 
        handler = new Handler(engine,dsc);

        //Make handler the target contracts
        targetContract(address(handler));
    }

    function invariant_protocolMustBeOverCollateralized() public {
        uint256 totalWETH = weth.balanceOf(address(engine));
        uint256 totalWBTC = wbtc.balanceOf(address(engine));

        uint256 wethValue = engine.getUSDValue(address(weth),totalWETH);
        uint256 wbtcValue = engine.getUSDValue(address(wbtc),totalWBTC);

        uint256 totalCollateralValue = wethValue + wbtcValue;

        uint256 totalDSC = dsc.totalSupply();

        console.log("Total Collateral Value: ", totalCollateralValue);
        console.log("Total DSC Supply: ", totalDSC);

        assert(totalCollateralValue >= totalDSC);
    }
}