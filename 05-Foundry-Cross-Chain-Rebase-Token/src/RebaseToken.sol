// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Rebase Token
 * @author Abhishek Alimchandani
 * @notice This is a cross chain rebase token which incentivies users to deposit into the vault and gain interests in rewards
 * @notice The interest rates in the smart contract can only decrease 
 * @notice Each user will have their own interest rate that is the global interest rate at the time of depositing
 */
contract RebaseToken is ERC20,Ownable,AccessControl{
    //Errors
    error RebaseToken__TheInterestRateCanOnlyDecrease(uint256 oldInterestRate,uint256 newInterestRate);

    //State variables
    uint256 private s_interestRate = 5e10; //This is interest rate for one sec which 0.000000005% per second
    uint256 private constant PRECESION_FACTOR = 1e18;
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE");

    mapping (address user => uint256 interestRates) private s_userInterestRate;
    mapping (address user => uint256 timeStamp) private s_userLastUpdatedTimeStamp;

    //Events
    event InterestRateUpdated(uint256 indexed _newInterestRate);

    constructor () ERC20("Rebase Token","RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner{
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    /**
     * @notice This sets the new interest rate in the contract
     * @param _newInterestRate The new interest rate inside of the contract
     * @dev The interet rate can only decrease
     */
    function setInterestRate(uint256 _newInterestRate) external onlyOwner {
        if(_newInterestRate >= s_interestRate){
            revert RebaseToken__TheInterestRateCanOnlyDecrease(s_interestRate,_newInterestRate);
        }

        s_interestRate = _newInterestRate;
        emit InterestRateUpdated(_newInterestRate);
    }

    /**
     * @notice Get the principle balance of the user, This is the current number of tokens which have been minted to the user not including any interest that has accured since the last time the user has interact with the protocol
     * @param _user The user to get the principle balance
     */
    function principleBalanceOf(address _user) external view returns(uint256){
        return super.balanceOf(_user);
    }

    /**
     * @notice Mints rebase tokens to the user when they deposit into the vault.
     *         Automatically accrues and mints any pending interest from previous deposits
     *         before updating their interest rate and minting the new amount.
     * @param _to The address of the user receiving the minted tokens
     * @param _amount The amount of new tokens to mint (based on their new deposit)
     */
    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE){
        // 1. Mint any interest accrued from previous deposits using the user's old interest rate
        _mintAccruedInterest(_to);

        // 2. Update the user's interest rate to the current protocol rate for future accrual
        s_userInterestRate[_to] = s_interestRate;

        // 3. Mint new tokens based on the latest deposit
        _mint(_to, _amount);
    }

    /**
     * @notice This function is to burn the token from the user
     * @param _from The address of user to burn the token from
     * @param _amount The amount of tokens to burn
     */
    function burn(address _from,uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE){
        if(_amount == type(uint256).max){
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from,_amount);
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
        return (super.balanceOf(_user) * _calculateTheUserAcumulatedInterestsSinceLastUpdate(_user))/PRECESION_FACTOR;
    }

    /**
     * @notice Transfer tokens from one user to another
     * @param _recepient The user to transfer the tokens to
     * @param _amount The amount of tokens to transfer
     * @return True if transfer was successful
     */
    function transfer(address _recepient, uint256 _amount) public override returns(bool){
        //Before sending any kind of tokens we need to check if any interest has accured
        _mintAccruedInterest(msg.sender);

        //Similar thing we need to do for the recepient
        _mintAccruedInterest(_recepient);

        //If the user is sending for its complete balance
        if(_amount == type(uint256).max){
            _amount = balanceOf(msg.sender);
        }

        //Check if the recepient has a interest rate or else update with that of the sender
        if(balanceOf(_recepient) == 0){
            s_userInterestRate[_recepient] = s_userInterestRate[msg.sender];
        }

        return super.transfer(_recepient,_amount);
    }

    function transferFrom(address _sender,address _recepient,uint256 _amount) public override returns(bool){
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recepient);

        if(_amount == type(uint256).max){
            _amount = balanceOf(_sender);
        }

        if(balanceOf(_recepient) == 0){
            s_userInterestRate[_recepient] = s_userInterestRate[_sender];
        }

        return super.transferFrom(_sender,_recepient,_amount);
    }

    function _calculateTheUserAcumulatedInterestsSinceLastUpdate(address _user) internal view returns(uint256 linearInterest){
        // 1. Calculate the time since the last update
        // 2. Amount of linear growth (principal amount + (principal amount * user interest rate * time elapsed))
        // ==> principal amount(1 + (userInterestRate * timeElapsed))
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        linearInterest = PRECESION_FACTOR + (s_userInterestRate[_user] * timeElapsed);
    }

    /**
     * @notice Mint the accured interest to the user since the last time they have interacted with the protocol
     * @param _user The user to mint the accured intrest to
     */
    function _mintAccruedInterest(address _user) internal {
    // 1. Fetch the user's current principal balance (already minted tokens)
    uint256 previousPrincipalBalance = super.balanceOf(_user);
    // 2. Calculate their updated balance including accrued interest since the last update
    uint256 currentBalance = balanceOf(_user);
    // 3. Determine the interest amount by subtracting the principal from the updated balance
    uint256 balanceIncreased = currentBalance - previousPrincipalBalance;
    // 4. Update the user's last interest accrual timestamp to the current block time
    s_userLastUpdatedTimeStamp[_user] = block.timestamp;
    // 5. Mint the interest tokens to the user to reflect the growth
    _mint(_user,balanceIncreased);
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

    function getInterestRateOfContract() external view returns(uint256){
        return s_interestRate;
    }
}
