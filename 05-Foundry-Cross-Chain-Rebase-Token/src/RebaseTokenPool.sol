// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "ccip/contracts/src/v0.8/vendor/openzeppelin-solidity/v4.8.3/contracts/interfaces/IERC20.sol"; // Do not import it from openzeppelin directly it doesn't work 
import {Pool} from "ccip/contracts/src/v0.8/ccip/libraries/Pool.sol";
import {TokenPool} from "ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";
import {IRebaseToken} from "./Interfaces/IRebaseToken.sol";

contract RebaseTokenPool is TokenPool {
    constructor(IERC20 _token,address[] memory _allowlist, address _rmnProxy,address _router) TokenPool((_token),_allowlist,_rmnProxy,_router){

    }

    //So this function will be called when we are sending tokens from the source chain on which this Pool token is deployed to the source chain
    function lockOrBurn(Pool.LockOrBurnInV1 calldata lockOrBurnIn) external returns (Pool.LockOrBurnOutV1 memory lockOrBurnOut){
        _validateLockOrBurn(lockOrBurnIn); // This makes sure the token is supported, checking it is not cursed nothing is going wrong from RMN, checking its on allow list ,check its originating from onRamp

        address originalSender = lockOrBurnIn.originalSender;

        //Before we burn tokens we need to send interest rate but not sure why are we doing it here
        uint256 userInterestRate = IRebaseToken(address(i_token)).getUserInterestRate(originalSender);

        //Now we can burn the tokens
        //Now the reason we are burning tokens from this address is the main thing we need to give this contract the approvals before the ccip can send tokens, So basically we will have to approve the Router to do this for us
        IRebaseToken(address(i_token)).burn(address(this),lockOrBurnIn.amount);

        lockOrBurnOut = Pool.LockOrBurnOutV1({
            destTokenAddress: getRemoteToken(lockOrBurnIn.remoteChainSelector),
            destPoolData: abi.encode(userInterestRate)
        });
    }

    //If this tokenPool is receiving token then this function will be called
    function releaseOrMint(Pool.ReleaseOrMintInV1 calldata releaseOrMintIn) external returns (Pool.ReleaseOrMintOutV1 memory){
        _validateReleaseOrMint(releaseOrMintIn);

        //Getting user interest rate
        uint256 userInterestRate = abi.decode(releaseOrMintIn.sourcePoolData,(uint256));

        //Now we need go mint the tokens
        IRebaseToken(address(i_token)).mint(releaseOrMintIn.receiver,releaseOrMintIn.amount,userInterestRate);

        return Pool.ReleaseOrMintOutV1({
            destinationAmount: releaseOrMintIn.amount
        });
    }
}
