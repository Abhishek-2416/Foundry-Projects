// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
/**
 * @title Decentralized Exogenous StableCoin
 * @author Abhishek Alimchandani
 * @notice This is a ERC20 contract for the stablecoin system which will be governed by the DSC engine
 */
contract DecentralizedStableCoin is ERC20Burnable,Ownable {
    error DecentralizedStableCoin__MustBeMoreThanZero();
    error DecentralizedStableCoin__BurnAmountExceedsBalance();
    error DecentralizedStableCoin__NotZeroAddress();

    constructor() ERC20("DecentralizedStableCoin","DSC") Ownable(msg.sender){}

    function mint(address _to, uint256 _amount) external onlyOwner returns(bool){
        if(_to == address(0)){
            revert DecentralizedStableCoin__NotZeroAddress();
        }

        if(_amount == 0){
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }

        _mint(_to,_amount);
        return true;
    }

    //Removed OnlyOwner as it wasnt allowing bob to burn due to changes in OpenZepplein Ownable
    function burn(uint256 _amount) public override{
        uint256 balance = balanceOf(msg.sender);

        if(_amount <= 0){
            revert DecentralizedStableCoin__MustBeMoreThanZero();
        }

        if(balance < _amount){
            revert DecentralizedStableCoin__BurnAmountExceedsBalance();
        }


        //What this super keyword does is allows us to use a function directly from the parent's class
        super.burn(_amount); // <--- this bypasses the allowance check
    }
}