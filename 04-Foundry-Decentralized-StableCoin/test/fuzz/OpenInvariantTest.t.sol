// Here this must have our invariant which always hold true
// As per my understanding the invariants are the properties of our contract which should always hold true

//For example in our contract 
//1. The total supply of DSC should be less than the total value of collateral


// Getter view functions must never revert

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";


contract OpenInvariantTest is StdInvariant, Test {
    DecentralizedStableCoin dsc;
    DSCEngine engine;

    ERC20Mock weth;
    ERC20Mock wbtc;

    MockV3Aggregator wethUsdPriceFeed;
    MockV3Aggregator wbtcUsdPriceFeed;

    address[] public tokens;
    address[] public priceFeeds;

    //Constants
    int256 private constant WETH_STARTING_PRICE = 2000e8;
    int256 private constant WBTC_STARTING_PRICE = 20000e8;

    //addresses
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    function setUp() external {
        weth = new ERC20Mock("Wrapped Ether","WETH",msg.sender,1000e18);
        wbtc = new ERC20Mock("Wrapped Bitcoin","WBTC",msg.sender,1000e18);

        wethUsdPriceFeed = new MockV3Aggregator(8,WETH_STARTING_PRICE);
        wbtcUsdPriceFeed = new MockV3Aggregator(8,WBTC_STARTING_PRICE);

        dsc = new DecentralizedStableCoin();

        tokens.push(address(weth));
        priceFeeds.push(address(wethUsdPriceFeed));

        tokens.push(address(wbtc));
        priceFeeds.push(address(wbtcUsdPriceFeed));

        engine = new DSCEngine(tokens,priceFeeds,address(dsc));

        targetContract(address(engine)); //This is a difference here

        //Intial setup
        dsc.transferOwnership(address(engine));

        weth.mint(bob,100e18);
        weth.mint(alice,100e18);

        vm.prank(bob);
        weth.approve(address(engine),100e18);

        vm.prank(bob);
        dsc.approve(address(engine),100e18);

        vm.prank(alice);
        weth.approve(address(engine),1000e18);
        
        vm.prank(alice);
        dsc.approve(address(engine),100e18);
    }

    function invariant_protocolMustHaveMoreValueThanTotalSupply() public view {
        // Get the value of all the collateral in the protocol 
        uint256 totalSupply = dsc.totalSupply();
        uint256 totalWETHDeposited = IERC20(address(weth)).balanceOf(address(engine));
        uint256 totalWBTCDeposited = IERC20(address(wbtc)).balanceOf(address(engine));

        uint256 wethValue = engine.getUSDValue(address(weth),totalWETHDeposited);
        uint256 wbtcValue = engine.getUSDValue(address(wbtc),totalWBTCDeposited);

        console.log(wethValue);
        console.log(wbtcValue);
        console.log(totalSupply);

        assert((wethValue + wbtcValue) >= totalSupply);
        // Compare it to all the debt (DSC)
    }
}




/**
 * This wont run for the our contract as it is complex and then we need to run selectors so it is better we use the Handlers
 */