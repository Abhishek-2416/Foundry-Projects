// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {console} from "forge-std/console.sol";

/**
 * @title DSCEngine
 * @author Abhishek Alimchandani
 * 
 * The stablecoin has the following properties
 * - Exogenous
 * - Dollar Pegged
 * - Algorithmically Stable
 * 
 * And the DSC system should always be over collatralized 
 * 
 * It is somewhat similar to DAI token, if the DAI had no goveranance,and was only backed by wETH and wBTC
 * 
 * @notice This is designed to mantain the contract at $1 and it will handle all logic like minitng,redeeming DSC as well as depositing and withdrawing collateral
 */
contract DSCEngine is ReentrancyGuard {
    //Errors
    error DSCEngine__MintFailed();
    error DSCEngine__TransferFailed();
    error DSCEngine__TokenIsNotAllowed();
    error DSCEngine__InsufficentBalance();
    error DSCEngine__HealthFactorIsFine();
    error DSCEngine__BreaksHealthFactor();
    error DSCEngine__HealthFactorNotImproved();
    error DSCEngine__TheAmountShouldBeMoreThanZero();
    error DSCEngine__TokenAddressAndPriceFeedAddressShouldBeSameLength();

    //Variables
    uint256 private constant LIQUIDATION_THRESHOLD = 50; //Indicates we need to be 200% collateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant LIQUIDATION_BONUS = 10; //This means a 10% bonus 
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    mapping (address token => address priceFeed) private s_priceFeeds;
    mapping (address user => mapping ( address token => uint amount )) private  s_userCollalteralDeposited;
    mapping (address user => uint256 amountDscMinted) private s_DSCMinted;

    address[] private s_collateralTokens;
    DecentralizedStableCoin private immutable i_dsc;

    //Events 
    // `indexed` makes params searchable in logs (e.g., by user or token)
    event CollateralDeposited(address indexed user,address indexed tokenAddress, uint256 indexed amount);
    event CollateralRedeemed(address indexed redeemedFrom, address indexed redeemTo, address indexed token, uint256 amount);

    //Modifiers
    modifier moreThanZero(uint256 amount){
        if(amount == 0){
            revert DSCEngine__TheAmountShouldBeMoreThanZero();
        }
        _;  
    }
    
    // Checks if the token is allowed by verifying it has a registered price feed.
    // Using mapping lookup is gas-efficient (O(1)) compared to looping through arrays (O(n)).
    // If s_priceFeeds[token] returns address(0), the token is not supported.
    modifier isAllowedToken(address token) {
        if(s_priceFeeds[token] == address(0)){
            revert DSCEngine__TokenIsNotAllowed();
        }
        _;
    }

    //External Functions
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddress,address dscAddress) {
        if(tokenAddresses.length != priceFeedAddress.length){
            revert DSCEngine__TokenAddressAndPriceFeedAddressShouldBeSameLength();
        }

        for(uint256 i = 0; i < tokenAddresses.length; i++){
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddress[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }

        i_dsc = DecentralizedStableCoin(dscAddress);
    }
    
    /**
     * 
     * @param tokenCollateralAddress The address of the token which will be deposited as collateral
     * @param amountCollateral The amount of collateral to deposit
     */
    function depositCollateral(address tokenCollateralAddress,uint256 amountCollateral) public moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) nonReentrant {
        s_userCollalteralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender,tokenCollateralAddress,amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender,address(this),amountCollateral);
        if(!success){
            revert DSCEngine__TransferFailed();
        }
    }

    function mintDSC(uint256 amountDscToMint) public moreThanZero(amountDscToMint) {
        //So before this it was allowing 1:1 minting and we basically dont want that else everyone will be liquidated lol

        //Checking the old health factor
        _revertIfHealthFactorIsBroken(msg.sender);

        uint256 newTotalDSC = s_DSCMinted[msg.sender] + amountDscToMint;

        //Current value of the collateral
        uint256 collateralValueInUSD = getAccountCollateralValueInUsd(msg.sender);

        //This would be health factor after the mint
        uint256 newHealthFactor = _calculateHealthFactor(newTotalDSC,collateralValueInUSD);

        if(newHealthFactor < MIN_HEALTH_FACTOR){
            revert DSCEngine__BreaksHealthFactor();
        }

        s_DSCMinted[msg.sender] += amountDscToMint;

        (bool success) = i_dsc.mint(msg.sender,amountDscToMint);

        if(!success){
            revert DSCEngine__MintFailed();
        }
    }

    /**
     * 
     * @param tokenCollateralAddress The address of token to deposit as a collateral
     * @param amountCollateral The amount of collateral to deposit
     * @param amountDscToMint The amount of DSC to mint
     * @notice This function will deposit your collateral and mint DSC in one transaction
     */
    function depositCollateralAndMintDSC(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountDscToMint) external moreThanZero(amountCollateral) moreThanZero(amountDscToMint) isAllowedToken(tokenCollateralAddress){
        depositCollateral(tokenCollateralAddress,amountCollateral);
        mintDSC(amountDscToMint);
    }

    function burnDSC(uint256 DSCAmountToBurn,address onBehalfOf,address DSCFrom) public moreThanZero(DSCAmountToBurn) {
        s_DSCMinted[msg.sender] -= DSCAmountToBurn;

        bool success = i_dsc.transferFrom(DSCFrom, address(this), DSCAmountToBurn);
        // This conditional is hypothetically unreachable
        if (!success) {
            revert DSCEngine__TransferFailed();
        }
        i_dsc.burnFrom(msg.sender,DSCAmountToBurn);

        _revertIfHealthFactorIsBroken(msg.sender); //Not at all likely for this to break
    }

    function _redeemCollateral(address from,address to,address tokenCollateralAddress, uint256 amountCollateral) private moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) {
        if (s_userCollalteralDeposited[from][tokenCollateralAddress] < amountCollateral) {
            revert DSCEngine__InsufficentBalance();
        }

        s_userCollalteralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from,to,tokenCollateralAddress,amountCollateral);

        //I was thinking we would first checkin the condition that their HealthFactor is good or not when their collateral is removed, but we are doing the transfer first in case their health factor isnt good after then we will simply revert the transaction
        bool success = IERC20(tokenCollateralAddress).transfer(to,amountCollateral);
        if(!success){
            revert DSCEngine__TransferFailed();
        }
    }

    // To redeem collateral:
    // 1. Their health factor should be greater than 1 AFTER THE COLLATERAL IS PULLED
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral) public moreThanZero(amountCollateral) nonReentrant{
        _redeemCollateral(msg.sender,msg.sender,tokenCollateralAddress,amountCollateral);
        // 🚨 Only check health factor if they have DSC minted
        if (s_DSCMinted[msg.sender] > 0) {
            _revertIfHealthFactorIsBroken(msg.sender);
        }
    }

    /**
     * 
     * @param tokenCollateralAddress The collateral Address to redeem 
     * @param amountCollateral The amount of collateral to redeem
     * @param DSCAmount The amount of DSC to burn
     * @notice THis function will burn DSC and redeem underlying collateral
     */
    function redeemCollateralForDSC(address tokenCollateralAddress,uint256 amountCollateral,uint256 DSCAmount) external moreThanZero(amountCollateral) moreThanZero(DSCAmount) isAllowedToken(tokenCollateralAddress){
        burnDSC(DSCAmount,msg.sender,msg.sender);
        redeemCollateral(tokenCollateralAddress,amountCollateral); //This checks for health factor as well
    }

    function getTokenAmountFromUSD(address token, uint256 usdAmountInWei) public view returns(uint256){
        //First we are getting the current price of the token
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (,int256 price,,,) = priceFeed.latestRoundData();
        return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    }

    // If someone is almost undercollateralized, we will pay you to liquidate them
    /**
     * 
     * @param collateralAddress The ERC20 collateral to liquidate
     * @param user The person or the user we want to liquidate whose health factor is broken
     * @param debtToCover The amount of DSC you want to burn to improve the user's health factor
     * 
     * @notice You can partially liquidate a user.
     * @notice You will get an liquidation bonus to do this
     * @notice This function assumes the protocol will 200% overcollateralized in order to work
     * @notice We cannot maintain this system if the protocol were 100% or less collateralized, then we wouldn't be able to incentive the liquidators
     * 
     * Follows CEI: Checks, Effects, Interactions
     */
    function liquidate(address collateralAddress, address user, uint256 debtToCover) 
    external 
    moreThanZero(debtToCover) 
    isAllowedToken(collateralAddress) 
    nonReentrant 
{
    // Need to check for user if he is actually near liquidation
    uint256 startingUserHealthFactor = _healthFactor(user);
    console.log(startingUserHealthFactor);

    if(startingUserHealthFactor >= MIN_HEALTH_FACTOR){
        revert DSCEngine__HealthFactorIsFine();
    }

    uint256 tokenAmountFromDebtCovered = getTokenAmountFromUSD(collateralAddress, debtToCover);
    console.log(tokenAmountFromDebtCovered);

    // We are giving the liquidator a 10% bonus for the amount he liquidated
    uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
    uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;
    _redeemCollateral(user, msg.sender, collateralAddress, totalCollateralToRedeem);

    // Burn the DSC
    burnDSC(debtToCover, user, msg.sender);

    // Now we check the health factor again - ensure liquidation didn't make things worse
    uint256 endingUserHealthFactor = _healthFactor(user);
    console.log(endingUserHealthFactor);

    // Fixed check: Only revert if the health factor got worse
    // This allows legitimate liquidations that improve the position
    if(endingUserHealthFactor < startingUserHealthFactor){
        revert DSCEngine__HealthFactorNotImproved();
    }

    // Now if this affects the liquidator's health factor then also we need to revert
    _revertIfHealthFactorIsBroken(msg.sender);
}

    function getUSDValue(address tokenCollateralAddress, uint256 amount) moreThanZero(amount) isAllowedToken(tokenCollateralAddress) public view returns(uint256){
        (,int256 price,,,) = AggregatorV3Interface(s_priceFeeds[tokenCollateralAddress]).latestRoundData();
        
        // Chainlink price feeds return prices with 8 decimals (1e8).
        // We multiply by 1e10 to scale it to 18 decimals (1e18), which matches the standard ERC20 token decimal format.
        // This ensures consistent precision across the calculation when converting token amount to USD value.
        // The formula is: (price * 1e10) * amount / 1e18, which maintains 18 decimal precision in the result.
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    function getAccountCollateralValueInUsd(address user) public view returns(uint256 totalCollateralValue) {
        //Loop through each collateral token and get the amount they have deposited and map it
        for (uint256 i = 0; i < s_collateralTokens.length; i++){
            address token =  s_collateralTokens[i];
            uint256 amount = s_userCollalteralDeposited[user][token];
            totalCollateralValue += getUSDValue(token,amount);
        }

        return totalCollateralValue;
    }

    function _getAccountInformation(address user) private view returns(uint256 totalDscMinted,uint256 collateralValueInUSD){
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUSD = getAccountCollateralValueInUsd(user);
    }

    function _calculateHealthFactor(uint256 totalDSCMinted,uint256 collateralValueInUsd) public pure returns(uint256) {
        /**
         * Example:
         * - Collateral value = $1000
         * - LIQUIDATION_THRESHOLD = 50
         * - Adjusted = ($1000 * 50) / 100 = $500
         * - DSC minted = $400
         * - Health Factor = $500 / $400 = 1.25 (safe)
        */
        if(totalDSCMinted == 0) return type(uint256).max;

        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalDSCMinted;
    }

    /**
     * This returns how close to liquidation a user is
     * If a user goes below 1, they can get liquidated
     */
    function _healthFactor(address user) public view returns (uint256) {
    // 1. Get total DSC minted and total collateral value (in USD)
    (uint256 totalDSCMinted, uint256 collateralValueInUSD) = _getAccountInformation(user);
    return _calculateHealthFactor(totalDSCMinted, collateralValueInUSD);
    
    }

    function _revertIfHealthFactorIsBroken(address user) internal view {
        //1. Check Health Factor
        //2. Revert if it isn't sufficent

        uint256 userHealthFactor = _healthFactor(user);
        if(userHealthFactor < MIN_HEALTH_FACTOR){
            revert DSCEngine__BreaksHealthFactor();
        }
    }


    //Getter functions
    function getUserCollateral(address user, address token) public view returns (uint256) {
        return s_userCollalteralDeposited[user][token];
    }

    function getContractTokenBalance(address token) external view returns (uint256) {
        return IERC20(token).balanceOf(address(this));
    }

    function getDSCMinted(address user) external view returns(uint256){
        return s_DSCMinted[user];
    }

    function getAccountInformation(address user) external view returns(uint256 totalDscMinted,uint256 collateralValueInUS){
        return _getAccountInformation(user);
    }

    function getCollateralTokens() external view returns(address[] memory){
        return s_collateralTokens;
    }

    function mintDscOldWay(uint256 amountDscToMint) public moreThanZero(amountDscToMint) nonReentrant {
        s_DSCMinted[msg.sender] += amountDscToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_dsc.mint(msg.sender, amountDscToMint);

        if (minted != true) {
            revert DSCEngine__MintFailed();
        }
    }
}