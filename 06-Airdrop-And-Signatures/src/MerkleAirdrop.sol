// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MerkleAirdrop {
    using SafeERC20 for IERC20;
    //So instead of having all the claimers inside of an array and then looping through the array again and again to check if the user is present or not
    //This works but the amount of gas required will extortionary
    //Hence we will be using Merkle proofs

    address[] claimers;
    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_airdropToken;

    mapping(address claimer => bool claimed) private s_hasClaimed; 

    //Errors
    error MerkleAirdrop__AlreadyClaimed();
    error MerkleAirdrop__InvalidProof();

    //Evevnts
    event Claim(address indexed account,uint256 indexed amount);

    constructor(bytes32 merkleRoot,IERC20 airdropToken){
        merkleRoot = i_merkleRoot;
        airdropToken = i_airdropToken;
    }

    /**
     * 
     * @param account The address of the who wants to claim the airdrop
     * @param amount The amount of tokens they want to claim
     * @param merkleProof The intermediate hashes that are required in order to be able to calculate the root
     */
    function claim(address account,uint256 amount,bytes32[] calldata merkleProof) external{
        if(s_hasClaimed[account]){
            revert MerkleAirdrop__AlreadyClaimed();
        }

        //We calculate the has using the amount and the account
        //Here the hash which we get is the leaf node

        //We hash it twice to prevent the second preimage attack
        //This is the standard way we encode and hash leaf nodes
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account,amount))));

        if(!MerkleProof.verify(merkleProof,i_merkleRoot,leaf)){
            revert MerkleAirdrop__InvalidProof();
        }

        s_hasClaimed[account] = true;

        emit Claim(account,amount);

        //Now once we have verified that they are a part of the list, we can mint them the tokens
        IERC20(i_airdropToken).safeTransfer(account,amount);
    }

    //Getter function
    function getMerkleRoot() external view returns(bytes32){
        return i_merkleRoot;
    }

    function getAirdropToken() external view returns(IERC20){
        return i_airdropToken;
    }

    
}