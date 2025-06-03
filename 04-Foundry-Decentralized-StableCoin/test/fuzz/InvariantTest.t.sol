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


contract InvariantTest is StdInvariant, Test {
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
}