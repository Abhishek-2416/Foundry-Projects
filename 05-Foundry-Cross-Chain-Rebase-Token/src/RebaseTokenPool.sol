// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Pool} from "ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";
import {TokenPool} from "ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";

contract RebaseTokenPool is TokenPool {
    constructor(ERC20 _token,address[] memory _allowlist, address _rmnProxy,address _router) TokenPool(_token,_allowlist,_rmnProxy,_router){

    }

    //So this function will be called when we are sending tokens from the source chain on which this Pool token is deployed to
    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn) external returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut){
        _validateLockOrBurn(lockOrBurnIn);
    }

    //If this tokenPool is receiving token then this function will be called
    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn) external returns (Pool.ReleaseOrMintOutV1 memory){
        _validateReleaseOrMint(releaseOrMintIn);
    }
}
