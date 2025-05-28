// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {DecentralizedStableCoin} from "./DecentralizedStableCoin.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

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
    error DSCEngine__TheAmountShouldBeMoreThanZero();
    error DSCEngine__BreaksHealthFactor(uint256 healthFactorValue);
    error DSCEngine__TokenAddressAndPriceFeedAddressShouldBeSameLength();

    //Variables
    uint256 private constant LIQUIDATION_THRESHOLD = 50; //Indicates we need to be 200% collateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant PRECISION = 1e18;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;

    mapping (address token => address priceFeed) private s_priceFeeds;
    mapping (address user => mapping ( address token => uint amount )) private s_userCollalteralDeposited;
    mapping (address user => uint256 amountDscMinted) private s_DSCMinted;

    address[] private s_collateralTokens;
    DecentralizedStableCoin private immutable i_dsc;

    //Events 
    // `indexed` makes params searchable in logs (e.g., by user or token)
    event CollateralDeposited(address indexed user,address indexed tokenAddress, uint256 indexed amount);

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
    function depositCollateral(address tokenCollateralAddress,uint256 amountCollateral) external moreThanZero(amountCollateral) isAllowedToken(tokenCollateralAddress) nonReentrant {
        s_userCollalteralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender,tokenCollateralAddress,amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender,address(this),amountCollateral);
        if(!success){
            revert DSCEngine__TransferFailed();
        }
    }

    function mintDSC(uint256 amountDscToMint) external moreThanZero(amountDscToMint) {
        _revertIfHealthFactorIsBroken(msg.sender);
        s_DSCMinted[msg.sender] += amountDscToMint;
        (bool success) = i_dsc.mint(msg.sender,amountDscToMint);

        if(!success){
            revert DSCEngine__MintFailed();
        }
    }

    function depositCollateralAndMintDSC() external {}

    function redeemCollateralForDSC() external {}

    function redeemCollateral() external {}

    function burnDSC() external {}

    function liquidate() external {}

    function getHealthFactor() external {}

    //Private and Internal Functions

    function getUSDValue(address tokenCollateralAddress, uint256 amount) public view returns(uint256){
        (,int256 price,,,) = AggregatorV3Interface(s_priceFeeds[tokenCollateralAddress]).latestRoundData();
        
        // Chainlink price feeds return prices with 8 decimals (1e8).
        // We multiply by 1e10 to scale it to 18 decimals (1e18), which matches the standard ERC20 token decimal format.
        // This ensures consistent precision across the calculation when converting token amount to USD value.
        // The formula is: (price * 1e10) * amount / 1e18, which maintains 18 decimal precision in the result.
        return ((uint256(price) * 1e10) * amount) / 1e18;
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

    function _calculateHealthFactor(
    uint256 totalDSCMinted,
    uint256 collateralValueInUSD
) internal pure returns (uint256) {
    /**
     * Example:
     * - Collateral value = $1000
     * - LIQUIDATION_THRESHOLD = 50
     * - Adjusted = ($1000 * 50) / 100 = $500
     * - DSC minted = $400
     * - Health Factor = $500 / $400 = 1.25 (safe)
     */
    if (totalDSCMinted == 0) return type(uint256).max;

    uint256 collateralAdjustedForThreshold =
        (collateralValueInUSD * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

    return (collateralAdjustedForThreshold * PRECISION) / totalDSCMinted;
}

    /**
     * This returns how close to liquidation a user is
     * If a user goes below 1, they can get liquidated
     */
    function _healthFactor(address user) private view returns (uint256) {
    // 1. Get total DSC minted and total collateral value (in USD)
    (uint256 totalDSCMinted, uint256 collateralValueInUSD) = _getAccountInformation(user);
    return _calculateHealthFactor(totalDSCMinted, collateralValueInUSD);
}
    function _revertIfHealthFactorIsBroken(address user) internal view {
        //1. Check Health Factor
        //2. Revert if it isn't sufficent

        uint256 userHealthFactor = _healthFactor(user);
        if(userHealthFactor < MIN_HEALTH_FACTOR){
            revert DSCEngine__BreaksHealthFactor(userHealthFactor);
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
}