// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IRebaseToken} from "./Interfaces/IRebaseToken.sol";

/**
 * @title Vault contract
 * @author Abhishek Alimchandani
 * @notice Here this is the main contract with which the user will interact with, all the functions like deposit collateral,claim rewards and all those things
 * 
 * 1. We need to pass the address of the rebase token in the constructor
 * 2. Create a deposit function which accpets the collateral and mint the tokens to the user equal to the amount of collateral they have deposited
 * 3. Create a redeem function which burns the tokens from the user and then send them back their collateral
 * 4. Create a way to add rewards into the vault
 */
contract Vault{
    IRebaseToken private immutable i_rebaseToken;

    //Events
    event Deposited(address indexed user, uint256 indexed amount);
    event Redeem(address indexed user,uint256 indexed amount);

    //Errors
    error Vault__RedeemFailed();

    constructor(IRebaseToken _rebaseTokenAddress){
        i_rebaseToken = _rebaseTokenAddress;
    }

    // receive function to be able to send collateral to the contract
    receive() external payable{}

    /**
     * @notice This function is used to deposit collateral into the value in order to receive the rebase tokens
     * @dev Here we are first depositing the amount of collateral
     * And then we are minting the tokens from the rebase tokens, directly to the user who had deposited collateral
     */
    function deposit() external payable{
        //But also need to get the interest rate, now if you why in the deposit function this is becuase the CCIP router when it deposits the token from one chain to the other it will then need the interet rate of the user 
        uint256 interestRate = i_rebaseToken.getInterestRate();
        // We need to use the amount of collateral the user has sent to mint tokens to the user
        (i_rebaseToken).mint(msg.sender,msg.value,interestRate);
        emit Deposited(msg.sender,msg.value);
    }

    /**
     * @notice Users can redeem their collateral by putting in back the Rebase tokens
     * @dev Here we first need to burn the rebase tokens we receive from the user
     * Then we need to transfer them back their collateral
     */
    function redeem(uint256 _amount) external {
        if(_amount == type(uint256).max){
            _amount = i_rebaseToken.balanceOf(msg.sender);
        }
        // Burn their tokens first
        i_rebaseToken.burn(msg.sender,_amount);

        // Now send them the collateral
        (bool success,) = payable(msg.sender).call{value: _amount}("");

        if(!success){
            revert Vault__RedeemFailed();
        }

        emit Redeem(msg.sender,_amount);
    }

    // Getter functions
    function getTheAddressOfRebaseToken() external view returns(address){
        return address(i_rebaseToken);
    }
}