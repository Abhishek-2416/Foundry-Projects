// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test,console} from "forge-std/Test.sol";
import {BMWToken} from "../src/BMWToken.sol";
import {MerkleAirdrop} from "../src/MerkleAirdrop.sol";

contract TestMerkleAirdrop is Test{
    MerkleAirdrop public airdrop;
    BMWToken public token;

    address user = 0x6CA6d1e2D5347Bfab1d91e883F1915560e09129D;
    uint256 userPrivKey;

    bytes32 public ROOT = 0xaa5d581231e596618465a56aa0f5870ba6e20785fe436d5bfb82b08662ccc7c4;
    uint256 amountToClaim = 25000000000000000000;

    bytes32 proof1 = 0x0fd7c981d39bece61f7499702bf59b3114a90e66b51ba2c53abdf7b62986c00a;
    bytes32 proof2 = 0xe5ebd1e1b5a5478a944ecab36a9a954ac3b6b8216875f6524caa7a1d87096576;
    bytes32[] public PROOF = [proof1,proof2];


    function setUp() public {
        token = new BMWToken();
        airdrop = new MerkleAirdrop(ROOT,token);
    }

    function testTheUserCanClaim() public {
        uint256 startingBalance = token.balanceOf(user);

        vm.prank(user);
        airdrop.claim(user,amountToClaim,PROOF);

        uint256 endingBalance = token.balanceOf(user);
        assertEq(endingBalance,startingBalance+amountToClaim);
    }
}