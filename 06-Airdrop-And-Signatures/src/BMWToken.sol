// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract BMWToken is ERC20, Ownable {
    constructor() ERC20("BMWToken","BMW") Ownable(msg.sender){}

    function mint(address user,uint256 amount)external onlyOwner{
        _mint(user,amount);
    }
}