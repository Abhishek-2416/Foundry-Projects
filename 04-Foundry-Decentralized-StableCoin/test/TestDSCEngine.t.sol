// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from 'forge-std/Test.sol';
import {console} from "forge-std/console.sol";
import {DSCEngine} from "../src/DSCEngine.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {DecentralizedStableCoin} from "../src/DecentralizedStableCoin.sol";

contract TestDSCEngine is Test {
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    ERC20Mock weth;
    MockV3Aggregator wethUsdPriceFeed;

    //Events
    event CollateralDeposited(address indexed user,address indexed tokenAddress, uint256 indexed amount);

    address[] tokens = new address[](1);
    address[] priceFeeds = new address[](1);

    int256 private constant STARTING_PRICE = 2000e8;
    uint256 private constant TRANSFER_AMOUNT = 10e18;

    //addresses
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    function setUp() external {
        weth = new ERC20Mock("Wrapped Ether","WETH",msg.sender,1000e18);
        wethUsdPriceFeed = new MockV3Aggregator(8,STARTING_PRICE);

        dsc = new DecentralizedStableCoin();

        tokens[0] = address(weth);
        priceFeeds[0] = address(wethUsdPriceFeed);

        engine = new DSCEngine(tokens,priceFeeds,address(dsc));

        //Intial setup
        dsc.transferOwnership(address(engine));

        weth.mint(bob,100e18);
        vm.prank(bob);
        weth.approve(address(engine),100e18);
    }

    // address private WETH_ADDRESS = address(weth); Still not getting why WETh_ADdress is returning 0x00

    //Deposit Collateral
    function testDepositCollateralAmountShallBeGreaterThanZero() external{
        vm.prank(bob);
        vm.expectRevert();
        engine.depositCollateral(address(weth),0);
    }

    function testWhenOtherNonAllowedCollateralIsDeposited() external {
        vm.prank(bob);
        vm.expectRevert();
        engine.depositCollateral(address(0),TRANSFER_AMOUNT);
    }

    function testTheDepositedCollateralGetsUpdated() external {
        vm.prank(bob);
        engine.depositCollateral(address(weth),TRANSFER_AMOUNT);

        assertEq(engine.getUserCollateral(bob, address(weth)), TRANSFER_AMOUNT);
    }

    function testTheDepositCollateralEmitsEventOnDeposit() external {
        vm.prank(bob);
        vm.expectEmit();
        emit CollateralDeposited(bob,address(weth),TRANSFER_AMOUNT);
        engine.depositCollateral(address(weth),TRANSFER_AMOUNT);
    }

    function testTheEngineContractReceivesCollateralWhenDepositedByUser() external {
        vm.prank(bob);
        engine.depositCollateral(address(weth),TRANSFER_AMOUNT);

        assertEq(engine.getContractTokenBalance(address(weth)),TRANSFER_AMOUNT);
    }

    //MintDSC

    modifier BaseConditionForMintDSC() {
        vm.prank(bob);
        engine.depositCollateral(address(weth),TRANSFER_AMOUNT);
        _;
    }

    function testCannotMintDSCIfAmountIsZero() external BaseConditionForMintDSC {
        vm.prank(bob);
        vm.expectRevert();
        engine.mintDSC(0);
    }

    function testDSCMintedBalanceIncreases() external BaseConditionForMintDSC{
        assertEq(engine.getDSCMinted(bob),0);

        vm.prank(bob);
        engine.mintDSC(TRANSFER_AMOUNT);

        assertEq(engine.getDSCMinted(bob),TRANSFER_AMOUNT);
    }

    function testUserDSCBalance() external BaseConditionForMintDSC {
        assertEq(dsc.balanceOf(bob),0 ether);

        vm.prank(bob);
        engine.mintDSC(TRANSFER_AMOUNT);

        assertEq(dsc.balanceOf(bob),TRANSFER_AMOUNT);
    }

    //Support Functions
    function testGetUSDValue() external view{
        uint256 ethAmount = 15e18;
        uint256 expectedUSD = 30000e18;
        uint256 actualUSD = engine.getUSDValue(address(weth),ethAmount);

        assertEq(expectedUSD,actualUSD);
    }

    function testAccountCollateralValueInUSD() external {
        vm.prank(bob);
        engine.depositCollateral(address(weth),TRANSFER_AMOUNT);

        uint256 expectedAccountCollateralValue = 20000e18;
        uint256 actualAccountCollateralValue = engine.getAccountCollateralValueInUsd(bob);
        assertEq(expectedAccountCollateralValue,actualAccountCollateralValue);
    }

    function testGetTheAccountInformation() external {
        vm.prank(bob);
        engine.depositCollateral(address(weth),TRANSFER_AMOUNT);

        uint256 expectedTotalDSCMinted = 0;
        uint256 expectedcollateralValueInUSD = 20000e18;

        (uint256 actualTotalDSCMinted, uint256 actualcollateralValueInUsd) = engine.getAccountInformation(bob);

        assertEq(expectedcollateralValueInUSD,actualcollateralValueInUsd);
        assertEq(expectedTotalDSCMinted,actualTotalDSCMinted);
    }

    function testCalculateHealthFactor() external {

    }
}