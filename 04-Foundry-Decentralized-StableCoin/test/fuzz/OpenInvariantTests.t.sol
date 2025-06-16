// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Fuzzing 
 * @author Abhishek Alimchandani
 * @notice Just getting to know the basics of fuzz testing
 * 
 * //So Invariants are properties of our system which should always hold true for the system
 * 
 * Stateless Fuzzing: Where the state of the previous run is discarded for every new run
 * Stateful fuzzing: Where the ending state of previous run is the starting state of the next run
 * 
 * Foundry Fuzz Test: Where Random data is given to one function
 * Invariant Test: Random data is provided to all the functions over the whole contract
 * 
 * Foundry Fuzzing = Stateless Fuzzing
 * Foundry Invariants = Stateful fuzzing
 */

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {StdInvariant} from "forge-std/StdInvariant.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";


contract OpenInvariantTests is StdInvariant {
    DSCEngine public engine;
    HelperConfig public config;
    DeployDSCEngine public deployer;
    DecentralizedStableCoin public dsc;

    address public weth;
    address public wbtc;

    //Constants
    uint256 depositAmount = 1000 ether;
    uint256 mintAmount = 100 ether;
    
    //address
    address public bob = address(1);

    function setUp() public {
        deployer = new DeployDSCEngine();
        (dsc,engine,config) = deployer.run();
        (,,weth,wbtc,) = config.activeNetworkConfig();

        //Target function for fuzzing
        targetContract(address(engine));
    }

    function invariant_ProtocolMustHaveMoreValueThanTotalSupply() public view  {
        uint256 totalSupply = dsc.totalSupply();

        uint256 totalWethDeposited = ERC20Mock(weth).balanceOf(address(engine));
        uint256 totalWbtcDeposited = ERC20Mock(wbtc).balanceOf(address(engine));

        uint256 wethValue = engine.getUSDValue(weth,totalWethDeposited);
        uint256 wbtcValue = engine.getUSDValue(wbtc,totalWbtcDeposited);

        uint256 totalValue = wethValue + wbtcValue;

        console.log("Total Value:",totalValue);
        console.log("Total Supply:",totalSupply);

        assert(totalValue >= totalSupply);
    }
}


/**
 * Okay this OpenInvariant Part of the test will fail according to me as our contract has modifiers
 */