// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title Rebase Token
 * @author Abhishek Alimchandani
 * @notice This is a cross chain rebase token which incentivies users to deposit into the vault and gain interests in rewards
 * @notice The interest rates in the smart contract can only decrease 
 * @notice Each user will have their own interest rate that is the global interest rate at the time of depositing
 */
contract RebaseToken is ERC20{
    //Errors
    error RebaseToken__TheInterestRateCanOnlyDecrease(uint256 oldInterestRate,uint256 newInterestRate);

    //State variables
    uint256 private s_interestRate = 5e10; //This is interest rate for one sec which 0.000000005% per second

    mapping (address user => uint256 interestRates) private s_userInterestRate;
    mapping (address user => uint256 timeStamp) private s_userLastUpdatedTimeStamp;

    //Events
    event InterestRateUpdated(uint256 indexed _newInterestRate);

    constructor () ERC20("Rebase Token","RBT"){}

    /**
     * @notice This sets the new interest rate in the contract
     * @param _newInterestRate The new interest rate inside of the contract
     * @dev The interet rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external {
        if(_newInterestRate >= s_interestRate){
            revert RebaseToken__TheInterestRateCanOnlyDecrease(s_interestRate,_newInterestRate);
        }

        s_interestRate = _newInterestRate;
        emit InterestRateUpdated(_newInterestRate);
    }

    /**
     * @notice Mint the user tokens when they deposit into the vault
     * @param _to The address of user we need to mint the tokens to
     * @param _amount The amount of tokens we need to mint
     */
    function mint(address _to,uint256 _amount) external {
        //If someone has already minted before and come along again deposit again and mint again, their interest rate will be update to the new interest rate
        
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to,_amount);

    }

    /**
     * @notice Calculate the balance for the user including the intrests rate that has acumulated since the last update
     * (principal balance ) + some interest that has acumulated
     * @param _user The user to calculate balance Of
     * @return THe balance of user including their interest
     */
    function balanceOf(address _user) public view override returns(uint256){
        // Get the current principal balance (The number of tokens which have actually been minted to the user)
        // Multiply the principal balance by the interest that has aculmulated in time since the balance is last updated
        return super.balanceOf(_user);

    }

    function _mintAccuredInterest(address _user) internal {
        // Find their current balance of rebase token which have been minted to them -> principal balance
        // Calculate their current balance including their interest. -> balanceOf
        // Calculate the number of tokens which are minted to the user
        // Call the _mint to mint the token to user
        // Set the user's last updated timestamp
    }

    //Getter function

    /**
     * @notice Gets the interest rate of the user
     * @param _user The address of the user to get the interest rate for 
     */
    function getUserInterestRate(address _user) external view returns(uint256 interestRate){
        return s_userInterestRate[_user];
    }

    function getUserLastUpdatedTimeStamp(address _user) external view returns(uint256 lastUpdatedTimeStamp){
        return s_userLastUpdatedTimeStamp[_user];
    }
}
