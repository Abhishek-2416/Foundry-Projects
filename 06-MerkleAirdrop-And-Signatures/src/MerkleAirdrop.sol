// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract MerkleAirdrop  {
    using SafeERC20 for IERC20;

    bytes32 private immutable i_merkleRoot;
    IERC20 private immutable i_airdropToken;
    mapping (address calimer => bool claimed) private s_hasClaimed;

    //Errors
    error MerkleAirdrop__InvalidProof();

    //Events
    event Claim(address indexed account,uint256 indexed amount);

    constructor(bytes32 merkleRoot,IERC20 airdropToken){
        i_merkleRoot = merkleRoot;
        i_airdropToken = airdropToken;
    }

    function claim(address account,uint256 amount,bytes32[] calldata merkleProof) external {
        // While using merkle proofs we hash it twice, to avoid hash collisions
        // Also know as second preimage attack
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(account,amount))));

        if(!MerkleProof.verify(merkleProof,i_merkleRoot,leaf)){
            revert MerkleAirdrop__InvalidProof();
        }

        s_hasClaimed[account] = true;

        emit Claim(account,amount);

        (i_airdropToken).safeTransfer(account,amount);
    }

    function getMerkleRoot() external view returns(bytes32){
        return i_merkleRoot;
    }

    function getAirdropToken() external view returns(IERC20){
        return i_airdropToken;
    }
}