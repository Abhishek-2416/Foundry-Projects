// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from 'forge-std/Test.sol';
import {console} from "forge-std/console.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {MockV3Aggregator} from "../mocks/MockV3Aggregator.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract TestDSCEngine is Test {
    DecentralizedStableCoin dsc;
    DSCEngine engine;
    ERC20Mock weth;
    MockV3Aggregator wethUsdPriceFeed;

    //Events
    event CollateralDeposited(address indexed user,address indexed tokenAddress, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemedFrom, address indexed redeemTo, address indexed token, uint256 amount);

    address[] public tokens;
    address[] public priceFeeds;

    int256 private constant STARTING_PRICE = 2000e8;
    uint256 private constant TRANSFER_AMOUNT = 10e18;

    //addresses
    address bob = makeAddr("bob");
    address alice = makeAddr("alice");

    function setUp() external {
        weth = new ERC20Mock("Wrapped Ether","WETH",msg.sender,1000e18);
        wethUsdPriceFeed = new MockV3Aggregator(8,STARTING_PRICE);

        dsc = new DecentralizedStableCoin();

        tokens.push(address(weth));
        priceFeeds.push(address(wethUsdPriceFeed));

        engine = new DSCEngine(tokens,priceFeeds,address(dsc));

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

    //Constructor Tests
    function testItRevertsWhenTheLengthOfAddressArraysIsNotEqual() public {
        tokens.push(alice);
        vm.expectRevert(DSCEngine.DSCEngine__TokenAddressAndPriceFeedAddressShouldBeSameLength.selector);
        new DSCEngine(tokens,priceFeeds,address(dsc));
    }

    //(Modifiers)
    function testTheDepositAmountCannotBeZero() external {
        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__TheAmountShouldBeMoreThanZero.selector);
        engine.depositCollateral(address(weth),0);
    }

    function testCannotDepositUnVerifiedToken() external {
        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__TokenIsNotAllowed.selector);
        engine.depositCollateral(alice,TRANSFER_AMOUNT);
    }

    function testTheCollateralDepositedGetsUpdated() external {
        assertEq(engine.getUserCollateral(bob,address(weth)),0);
        vm.prank(bob);
        engine.depositCollateral(address(weth),TRANSFER_AMOUNT);
        assertEq(engine.getUserCollateral(bob,address(weth)),TRANSFER_AMOUNT);
    }

    function testEventEmitedWhenCollateralIsDeposited() external {
        vm.prank(bob);
        vm.expectEmit();

        emit CollateralDeposited(bob,address(weth),TRANSFER_AMOUNT);

        engine.depositCollateral(address(weth),TRANSFER_AMOUNT);
    }

    function testTheUserBalanceReducesAfterDeposit() external {
        assertEq((weth).balanceOf(bob),100 ether);

        vm.prank(bob);
        engine.depositCollateral(address(weth),TRANSFER_AMOUNT);

        assertEq((weth).balanceOf(bob),90 ether);
    }

    function testTheCollateralTokenGetsTransferedToTheEngine() external {
        assertEq((weth).balanceOf(address(engine)),0);

        vm.prank(bob);
        engine.depositCollateral(address(weth),TRANSFER_AMOUNT);

        assertEq((weth).balanceOf(address(engine)),TRANSFER_AMOUNT);
    }

    function testThatDepositCollateralRevertsWhenTransferFails() external {
        //we need exact calldata for that function call
        /**
         * So vm.mockCall basically helps us to manipulate the output we make to an external call
         * "Hey, next time I call out to this contract with this exact data, don’t actually run it—just give me this fake result instead.
         */
        bytes memory callData = abi.encodeWithSelector(IERC20.transferFrom.selector,bob,address(engine),TRANSFER_AMOUNT);
        vm.mockCall(address(weth),callData,abi.encode(false));

        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        engine.depositCollateral(address(weth),TRANSFER_AMOUNT);
    }

    //Modifier Deposit Collateral
    modifier depositCollateral {
        vm.prank(bob);
        engine.depositCollateral(address(weth),TRANSFER_AMOUNT);
        _;
    }

    //MintDSC
    function testCannotMintMoreDSCIfHealthFactorIsBroken() depositCollateral external {
        vm.prank(bob);
        engine.mintDSC(1000e18);

        //Breaking the health factor now
        wethUsdPriceFeed.updateAnswer(1e8);

        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
        engine.mintDSC(100e18);
    }

    function testMintFailsIfNewAmountBreaksHealthFactor() depositCollateral external {
        vm.prank(bob);
        engine.mintDSC(1000e18);

        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
        engine.mintDSC(10000e18);
    }

    function testTheDSCMintedUpdates() depositCollateral external {
        assertEq(engine.getDSCMinted(bob),0);

        vm.prank(bob);
        engine.mintDSC(1000e18);

        assertEq(engine.getDSCMinted(bob),1000e18);
    }

    function testWhenDSCMintedTheUserBalanceIncreases() depositCollateral external {
        assertEq(dsc.balanceOf(bob),0);

        vm.prank(bob);
        engine.mintDSC(1000e18);

        assertEq(dsc.balanceOf(bob),1000e18);
    }

    function testItRevertsWhenMintFails() depositCollateral external {
        bytes memory callData = abi.encodeWithSelector(dsc.mint.selector,bob,TRANSFER_AMOUNT);
        vm.mockCall(address(dsc),callData,abi.encode(false));

        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__MintFailed.selector);
        engine.mintDSC(TRANSFER_AMOUNT);
    }

    // Deposit Collateral and Mint DSC
    function testDepositCollateralAndMintDSCWorks() external {
        vm.prank(bob);
        engine.depositCollateralAndMintDSC(address(weth),TRANSFER_AMOUNT,TRANSFER_AMOUNT);

        assertEq(engine.getUserCollateral(bob,address(weth)),TRANSFER_AMOUNT);
        assertEq(engine.getDSCMinted(bob),TRANSFER_AMOUNT);   
    }

    modifier depositCollateralAndMintDSC {
        vm.prank(bob);
        engine.depositCollateralAndMintDSC(address(weth),TRANSFER_AMOUNT,TRANSFER_AMOUNT);
        _;
    }

    //Burn DSC
    // function testTheDSCMintedGetsUpdatedWhenBurnt() depositCollateralAndMintDSC external {
    //     assertEq(engine.getDSCMinted(bob),TRANSFER_AMOUNT);

    //     vm.prank(bob);
    //     engine.burnDSC(TRANSFER_AMOUNT);

    //     assertEq(engine.getDSCMinted(bob),0);
    // }

    // function testTheDSCGetBurned() depositCollateralAndMintDSC external {
    //     assertEq((IERC20(dsc).balanceOf(bob)),TRANSFER_AMOUNT);

    //     vm.prank(bob);
    //     engine.burnDSC(TRANSFER_AMOUNT);

    //     assertEq((IERC20(dsc).balanceOf(bob)),0);
    // }

    //Redeem Collateral 
    function testCannotRedeemMoreThanWhatDeposited() depositCollateral external {
        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__InsufficentBalance.selector);
        engine.redeemCollateral(address(weth),100e18);
    }

    function testTheUserCollateralGetUpdatedWhenRedeemCollateral() depositCollateral external {
        console.log(TRANSFER_AMOUNT);

        vm.prank(bob);
        engine.redeemCollateral(address(weth),TRANSFER_AMOUNT);

        assertEq(engine.getUserCollateral(bob,address(weth)),0);
    }

    function testAnEventIsEmitedWhenCollateralIsRedeemed() depositCollateral external {
        vm.prank(bob);
        vm.expectEmit();

        emit CollateralRedeemed(bob,bob,address(weth),TRANSFER_AMOUNT);

        engine.redeemCollateral(address(weth),TRANSFER_AMOUNT);
    }
    
    function testTheCollateralTokensAreTransferedToUser() depositCollateral external {
        assertEq(IERC20(address(weth)).balanceOf(bob),90e18);

        vm.prank(bob);
        engine.redeemCollateral(address(weth),TRANSFER_AMOUNT);

        assertEq(IERC20(address(weth)).balanceOf(bob),100e18);        
    }

    function testRedeemCollateralFailsIfTransferToUserFails() depositCollateral external {
        bytes memory callData = abi.encodeWithSelector(IERC20.transfer.selector,bob,TRANSFER_AMOUNT);
        vm.mockCall(address(weth),callData,abi.encode(false));

        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__TransferFailed.selector);
        engine.redeemCollateral(address(weth),TRANSFER_AMOUNT);
    }

    function testCannotRedeemCollateralIfITBreaksHealthFactor() depositCollateral external {
        // Deposited $20k DSC minted $5k, threshold $10k
        vm.prank(bob);
        engine.mintDSC(5000e18);

        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
        engine.redeemCollateral(address(weth),6e18);
    }

    //Redeem Collateral For DSC
    function testCanRedeemCollateralByGivingOutDSC() depositCollateral external {
        vm.prank(bob);
        engine.mintDSC(5000e18);

        vm.prank(bob);
        engine.redeemCollateralForDSC(address(weth),6e18,4000e18);
    }

    //Liquidate
    /**
     * So here we are testing this scenario
     * Bob: Deposited 10 ETH == $20k then  
     *      mints 10 DSC == $1
     *      Now 1ETH = $1 so threshold is 50% , bob can get Liquidated
     * 
     * Alice Deposits
     */
    function testCannotLiquidateUserIfItsHealthFactorIsFine() depositCollateralAndMintDSC external {
        vm.prank(alice);
        vm.expectRevert(DSCEngine.DSCEngine__HealthFactorIsFine.selector);
        engine.liquidate(address(weth),bob,TRANSFER_AMOUNT);
    }

    // Get Account Collateral Value In USD
    function testGetTheTotalCollateralValueInUSD() depositCollateral external {
        uint256 expectedAccountValue = 20000e18;
        uint256 actualAccountValue = engine.getAccountCollateralValueInUsd(bob);
        assertEq(expectedAccountValue,actualAccountValue);

    }

    //Get Account Information
    function testGetTheAccountInformation() depositCollateral external {
        vm.prank(bob);
        engine.mintDSC(TRANSFER_AMOUNT);

        uint256 expectedTotalDSCMinted = 10e18;
        uint256 expectedcollateralValueInUSD = 20000e18;

        (uint256 actualTotalDSCMinted,uint256 actualcollateralValueInUSD) = engine.getAccountInformation(bob);

        assertEq(expectedTotalDSCMinted,actualTotalDSCMinted);
        assertEq(actualcollateralValueInUSD,actualcollateralValueInUSD);
    }
    
    //Calculate Heath Factor
    function testCalculateHealthFactorWhenNoDSCMinted() depositCollateral external{
        uint256 expectedHealthFactor = type(uint256).max;
        uint256 actualHealthFactor = engine._calculateHealthFactor(0,uint256 (STARTING_PRICE));
        assertEq(expectedHealthFactor,actualHealthFactor);
    }

    function testTheCalculateHealthFactorFunction() depositCollateral external {
        vm.prank(bob);
        engine.mintDSC(TRANSFER_AMOUNT);

        /**
         * Let say we have deposited 10 ether 
         * Current price is $2000
         * So makes our collateral to be valued at $20k
         * Now we have just minted $10 DSC
         * We have buffer of $10k i.e 50%
         * so 10,000 * 1e18 / 10
         */

        uint256 totalDSCMinted = engine.getDSCMinted(bob);
        uint256 totalCollateralValue = engine.getAccountCollateralValueInUsd(bob);

        uint256 actualHealthFactor = engine._calculateHealthFactor(totalDSCMinted,totalCollateralValue);
        uint256 expectedHealthFactor = 1e21;

        assertEq(actualHealthFactor,expectedHealthFactor);
    }

    //_healthFactor
    function testGetHealthFactor() depositCollateral external {
        vm.prank(bob);
        engine.mintDSC(TRANSFER_AMOUNT);





    }

    // Revert If Health factor is Broken
    function testFunctionRevertsIfHealthFactorIsBroken() depositCollateral external {
        vm.prank(bob);
        vm.expectRevert(DSCEngine.DSCEngine__BreaksHealthFactor.selector);
        engine.mintDSC(10001e18);
    }

}