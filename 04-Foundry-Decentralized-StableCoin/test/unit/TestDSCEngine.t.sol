// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {DeployDSCEngine} from "../../script/DeployDSCEngine.s.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract TestDSCEngine is Test {
    DSCEngine public engine;
    HelperConfig public config;
    DecentralizedStableCoin public dsc;

    //Events
    event CollateralDeposited(address indexed user,address indexed tokenAddress, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemedFrom, address indexed redeemTo, address indexed token, uint256 amount);

    //Creating Mock to test it on the Local Anvil
    address public weth;
    address public wbtc;

    address public wethUsdPriceFeed;
    address public wbtcUsdPriceFeed;

    //Address arrays
    address[] public tokens;
    address[] public priceFeeds;

    //addresses
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    //constants
    uint256 private constant APPROVAL_AMOUNT = 10000e18;
    uint256 private constant DEPOSIT_AMOUNT = 10 ether;
    uint256 private constant AMOUNT_DSC_TO_MINT = 1000e18;

    function setUp() external {
        DeployDSCEngine deployer = new DeployDSCEngine();
        (dsc,engine,config) = deployer.run();

        //Fetching the addresses and deploy keys
        (weth,wbtc,wethUsdPriceFeed,wbtcUsdPriceFeed,) = config.activeNetworkConfig();

        tokens = [weth,wbtc];
        priceFeeds = [wethUsdPriceFeed,wbtcUsdPriceFeed];

        //Approvals
        weth = config.getActiveNetworkConfig().weth;
        vm.startPrank(bob);
        ERC20Mock(weth).mint(bob,APPROVAL_AMOUNT);
        ERC20Mock(weth).approve(address(engine),APPROVAL_AMOUNT);
        dsc.approve(address(engine),APPROVAL_AMOUNT);
        vm.stopPrank();  

        // wbtc = config.getActiveNetworkConfig().wbtc;
        // vm.startPrank(bob);
        // ERC20Mock(wbtc).mint(bob,APPROVAL_AMOUNT);
        // ERC20Mock(wbtc).approve(address(engine),APPROVAL_AMOUNT);
        // dsc.approve(address(engine),APPROVAL_AMOUNT);
        // vm.stopPrank();      
    }

    //Constructor Tests
    function testItRevertsWhenTheLengthOfAddressArraysIsNotEqual() public {
        ERC20Mock abhiToken = new ERC20Mock("Abhishek","ABHI",bob,100000e18);
        tokens.push(address(abhiToken));

        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressAndPriceFeedAddressShouldBeSameLength.selector);
        new DSCEngine(tokens,priceFeeds,address(dsc));
    }

    //Modifiers Test
    function testTheDepositAmountCannotBeZero() external {
        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__TheAmountShouldBeMoreThanZero.selector);
        engine.depositCollateral(weth,0);
    }

    function testCannotDepositUnVerifiedToken() external {
        ERC20Mock abhiToken = new ERC20Mock("Abhishek","ABHI",bob,100000e18);

        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__TokenIsNotAllowed.selector);
        engine.depositCollateral(address(abhiToken),DEPOSIT_AMOUNT);
    }

    //Deposit Collateral
    function testTheCollateralDepositedGetsUpdated() external {
        assertEq(engine.getUserCollateral(bob,weth),0);
        vm.prank(bob);
        engine.depositCollateral(weth,DEPOSIT_AMOUNT);
        assertEq(engine.getUserCollateral(bob,weth),DEPOSIT_AMOUNT);
    }

    function testEventEmitedWhenCollateralIsDeposited() external {
        vm.prank(bob);
        vm.expectEmit();

        emit CollateralDeposited(bob,(weth),DEPOSIT_AMOUNT);

        engine.depositCollateral((weth),DEPOSIT_AMOUNT);
    }

    function testTheUserBalanceReducesAfterDeposit() external {
        assertEq(IERC20(weth).balanceOf(bob),APPROVAL_AMOUNT);

        vm.prank(bob);
        engine.depositCollateral(address(weth),DEPOSIT_AMOUNT);

        assertEq(IERC20(weth).balanceOf(bob),APPROVAL_AMOUNT - DEPOSIT_AMOUNT);
    }

    function testTheCollateralTokenGetsTransferedToTheEngine() external {
        assertEq(IERC20(weth).balanceOf(address(engine)),0);

        vm.prank(bob);
        engine.depositCollateral(address(weth),DEPOSIT_AMOUNT);

        assertEq(IERC20(weth).balanceOf(address(engine)),DEPOSIT_AMOUNT);
    }

    function testThatDepositCollateralRevertsWhenTransferFails() external {
        //we need exact calldata for that function call
        /**
         * So vm.mockCall basically helps us to manipulate the output we make to an external call
         * "Hey, next time I call out to this contract with this exact data, don’t actually run it—just give me this fake result instead.
         */
        bytes memory callData = abi.encodeWithSelector(IERC20.transferFrom.selector,bob,address(engine),DEPOSIT_AMOUNT);
        vm.mockCall((weth),callData,abi.encode(false));

        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        engine.depositCollateral((weth),DEPOSIT_AMOUNT);
    }

    //Modifier to Deposit Collateral
    modifier depositCollateral {
        vm.prank(bob);
        engine.depositCollateral(weth,DEPOSIT_AMOUNT); //10ether
        _;
    }

    //Mint DSC    
    function testMintWorks() external {
        vm.prank(bob);
        engine.depositCollateral(weth,DEPOSIT_AMOUNT);

        vm.prank(bob);
        engine.mintDSC(DEPOSIT_AMOUNT);
    }

    function testCannotMintMoreThanThreshold() depositCollateral external {
        /**
         * Bob deposited 10 ether
         * USD value is $20k
         * Threshold will be $10k tops
         */

        vm.prank(bob);
        engine.mintDSC(5000e18);

        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
        engine.mintDSC(6000e18);
    }

    function testTheDSCMintedIsUpdatedAfterUserMintsDSC() depositCollateral external {
        assertEq(engine.getDSCMinted(bob),0);

        vm.prank(bob);
        engine.mintDSC(AMOUNT_DSC_TO_MINT);

        assertEq(engine.getDSCMinted(bob),AMOUNT_DSC_TO_MINT);
    }

    function testTheAmountOfDSCIsAlsoUpdatedForUser() depositCollateral external {
        assertEq(IERC20(dsc).balanceOf(bob),0);
        console.log("Bob Balance Before:",IERC20(dsc).balanceOf(bob));

        vm.prank(bob);
        engine.mintDSC(AMOUNT_DSC_TO_MINT);

        console.log("Bob Balance After:",IERC20(dsc).balanceOf(bob));
        assertEq(IERC20(dsc).balanceOf(bob),AMOUNT_DSC_TO_MINT);
    }

    function testTheMintFailsIfTheDSCIsNotMintedForUser() depositCollateral external {
        bytes memory callData = abi.encodeWithSelector(dsc.mint.selector,bob,AMOUNT_DSC_TO_MINT);
        vm.mockCall(address(dsc),callData,abi.encode(false));

        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
        engine.mintDSC(AMOUNT_DSC_TO_MINT);
    }

    function testCannotMintMoreDSCIfHealthFactorIsBroken() depositCollateral external {
        console.log("Price Before:",MockV3Aggregator(wethUsdPriceFeed).latestAnswer());
        vm.prank(bob);
        engine.mintDSC(1e18);

        MockV3Aggregator(wethUsdPriceFeed).updateAnswer(1e8);
        console.log("Price After: ",MockV3Aggregator(wethUsdPriceFeed).latestAnswer());

        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
        engine.mintDSC(AMOUNT_DSC_TO_MINT);
    }

    //Deposit Collateral And Mint DSC
    function testDepositCollateralAndMintDSCWorks() external {
        vm.prank(bob);
        engine.depositCollateralAndMintDSC((weth),DEPOSIT_AMOUNT,AMOUNT_DSC_TO_MINT);

        assertEq(engine.getUserCollateral(bob,(weth)),DEPOSIT_AMOUNT);
        assertEq(engine.getDSCMinted(bob),AMOUNT_DSC_TO_MINT);   
    }

    //Modifier to Deposit Collateral And Mint DSC
    modifier depositCollateralAndMintDSC {
        vm.prank(bob);
        engine.depositCollateralAndMintDSC(weth,DEPOSIT_AMOUNT,AMOUNT_DSC_TO_MINT);
        _;
    }

    //Burn DSC
    function testTheDSCMintedUpdatesWhenDSCBurnt() depositCollateralAndMintDSC external {
        assertEq(engine.getDSCMinted(bob),AMOUNT_DSC_TO_MINT);
        console.log("BoB DSC balance Before:",engine.getDSCMinted(bob));

        vm.prank(address(bob));
        engine.burnDSC(AMOUNT_DSC_TO_MINT);

        console.log("BoB DSC balance After:",engine.getDSCMinted(bob));
        assertEq(engine.getDSCMinted(bob),0);
    }

    function testCannotBurnDSCIfTheTransferFails() depositCollateralAndMintDSC external {
        bytes memory callData = abi.encodeWithSelector(dsc.transferFrom.selector,bob,address(engine),AMOUNT_DSC_TO_MINT);
        vm.mockCall(address(dsc),callData,abi.encode(false));

        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        engine.burnDSC(AMOUNT_DSC_TO_MINT);
    }

    function testTheDSCTokensGetBurned() depositCollateralAndMintDSC external {
        assertEq((IERC20(dsc).balanceOf(bob)),AMOUNT_DSC_TO_MINT);
        vm.prank(bob);
        engine.burnDSC(AMOUNT_DSC_TO_MINT);
        assertEq((IERC20(dsc).balanceOf(bob)),0);
    }

    //Redeem Collateral
    function testTheAmountCollateralRequestedShouldntBeGreaterThanBalance() depositCollateral external {
        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__InsufficentBalance.selector);
        engine.redeemCollateral(weth,DEPOSIT_AMOUNT + AMOUNT_DSC_TO_MINT);
    }

    function testTheCollateralDepositedGetUpdated() depositCollateral external {
        assertEq(engine.getUserCollateral(bob,weth),DEPOSIT_AMOUNT);

        vm.prank(bob);
        engine.redeemCollateral(weth,DEPOSIT_AMOUNT);

        assertEq(engine.getUserCollateral(bob,weth),0);
    }

    function testAnEventIsEmitedWhenCollateralIsRedeemed() depositCollateral external {
        vm.prank(bob);
        vm.expectEmit();

        emit CollateralRedeemed(bob,bob,(weth),DEPOSIT_AMOUNT);

        engine.redeemCollateral((weth),DEPOSIT_AMOUNT);
    }

    function testRedeemCollateralRevertsIfTheTransferFails() depositCollateral external {
        bytes memory callData = abi.encodeWithSelector(IERC20.transfer.selector,bob,DEPOSIT_AMOUNT);
        vm.mockCall((weth),callData,abi.encode(false));

        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        engine.redeemCollateral(address(weth),DEPOSIT_AMOUNT);
    }

    function testRedeemCollateralRevertsIfHealthFactorBreaks() depositCollateral external {
        vm.prank(bob);
        engine.mintDSC(9000e18);

        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
        engine.redeemCollateral(weth,3 ether);
    }

    //Redeem Collateral For DSC
    function testAbleToRedeemCollateralByBurningDSC() depositCollateralAndMintDSC external{
        assertEq(engine.getDSCMinted(bob),AMOUNT_DSC_TO_MINT);
        assertEq(engine.getUserCollateral(bob,weth),DEPOSIT_AMOUNT);

        vm.prank(bob);
        engine.redeemCollateralForDSC(weth,DEPOSIT_AMOUNT,AMOUNT_DSC_TO_MINT);

        assertEq(engine.getDSCMinted(bob),0);
        assertEq(engine.getUserCollateral(bob,weth),0);
    }
}