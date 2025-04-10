// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract FundMe {
    AggregatorV3Interface public priceFeed;

    constructor(address _priceFeed){
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function getPrice() public view returns(uint256){
        (,int256 price,,,) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function getDecimals() public view returns(uint8){
        return priceFeed.decimals();
    }
}