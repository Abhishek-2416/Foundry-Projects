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
    error DSCEngine__TransferFailed();
    error DSCEngine__TokenIsNotAllowed();
    error DSCEngine__TheAmountShouldBeMoreThanZero();
    error DSCEngine__TokenAddressAndPriceFeedAddressShouldBeSameLength();

    //Variables
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
        s_DSCMinted[msg.sender] += amountDscToMint;
    }

    function depositCollateralAndMintDSC() external {}

    function redeemCollateralForDSC() external {}

    function redeemCollateral() external {}

    function burnDSC() external {}

    function liquidate() external {}

    function getHealthFactor() external {}

    //Private and Internal Functions

    function _getAccountInformation(address user) private view returns(uint256 totalDscMinted,uint256 collateralValueInUSD){
        totalDscMinted = s_DSCMinted[user];
        collateralValueInUSD = getAccountCollateralValueInUsd(user);
    }

    function getAccountCollateralValueInUsd(address user) public view returns(uint256 valueInUSD) {
        //Loop through each collateral token and get the amount they have deposited and map it
        for (uint256 i = 0; i < s_collateralTokens.length; i++){
            address token =  s_collateralTokens[i];
            uint256 amount = s_userCollalteralDeposited[user][token];
        }
    }

    function getUSDValue(address tokenCollateralAddress, uint256 amount) external view returns(int){
        (,int256 price,,,) = AggregatorV3Interface(s_priceFeeds[tokenCollateralAddress]).latestRoundData();
        return price;
    }

    /**
     * This returns how close to liquidation a user is
     * If a user goes below 1, they can get liquidated
     */
    function _healthFactor() private view returns(uint256) {
        //Total DSC minted
        //Total Collateral value
    }
    function revertIfHealthFactorIsBroken(address user) internal view {
        //Check Health Factor
        //Revert if it isn't sufficent
    } 
}