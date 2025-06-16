// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

//Handler is going to narrow down the way we call functions and this way we dont waste the number of runs
// So we can actually test it and find bugs

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {ERC20Mock} from "../mocks/ERC20Mock.sol";
import {DSCEngine} from "../../src/DSCEngine.sol";
import {DecentralizedStableCoin} from "../../src/DecentralizedStableCoin.sol";

contract Handler is Test{
    DSCEngine public engine;
    DecentralizedStableCoin public dsc;

    //Creating Mock
    ERC20Mock public weth;
    ERC20Mock public wbtc;
    
    address public USER = makeAddr("USER");
    uint256 public constant MAX_DEPOSIT = type(uint96).max;
    uint256 public constant MIN_DEPOSIT = 1e14; // minimum > 0 to avoid modifier reverts

    constructor(DSCEngine _engine,DecentralizedStableCoin _dsc){
        engine = _engine;
        dsc = _dsc;

        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);

        //Mint and approve collateral
        weth.mint(USER,100e18);
        wbtc.mint(USER,100e18);

        weth.approveInternal(USER, address(engine), type(uint256).max);
        wbtc.approveInternal(USER, address(engine), type(uint256).max);
    }

    function depositCollateral(uint256 seed,uint256 amount) public {
        ERC20Mock token = _getCollateral(seed);
        amount = bound(amount,MIN_DEPOSIT,MAX_DEPOSIT);

        vm.prank(USER);
        engine.depositCollateral(address(token),amount);
    }

    //Internal and private functions
    function _getCollateral(uint256 seed) private view returns(ERC20Mock){
        if(seed % 2 == 0){
            return weth;
        }else return wbtc;
    }
}