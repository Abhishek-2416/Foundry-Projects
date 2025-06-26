// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Vault} from "../src/Vault.sol";
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {IRebaseToken} from "../src/Interfaces/IRebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract TestRebaseToken is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    //addresses
    address public owner = makeAddr("owner");
    address public bob = makeAddr("bob");
    address public alice = makeAddr("alice");
    
    function setUp() public {
        vm.startPrank(owner);
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool _success,) = payable(address(vault)).call{value: rewardAmount}("");
        _success;
    }

    //Constructor Tests
    function testTheInterestRateOfRebaseToken() external view {
        uint256 expectedInterestRate = 5e10;
        uint256 actualInterestRate = rebaseToken.getInterestRateOfContract();
        assertEq(expectedInterestRate,actualInterestRate);
    }

    function testTheNameOfRebaseTokenIsCorrect() external view {
        string memory expectedName = "Rebase Token";
        string memory actualName = rebaseToken.name();

        assertEq(keccak256(abi.encodePacked(expectedName)),keccak256(abi.encodePacked(actualName)));
    }

    function testTheSymbolOfTokenIsCorrect() external view {
        string memory expectedSymbol = "RBT";
        string memory actualSymbol = rebaseToken.symbol();

        assertEq(keccak256(abi.encodePacked(expectedSymbol)),keccak256(abi.encodePacked(actualSymbol)));
    }

    //
    function testDepositLinear(uint256 amount) public {
        amount = bound(amount,1e5,type(uint96).max);

        vm.startPrank(bob);
        vm.deal(bob,amount);

        // Deposit to the vault 
        vault.deposit{value: amount}();

        // 1. Check our rebase balance
        uint256 rebaseTokenStartingBalance = rebaseToken.balanceOf(bob);
        assertEq(rebaseTokenStartingBalance,amount);

        // 2. Wrap time and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 rebaseTokenMiddleBalance = rebaseToken.balanceOf(bob);
        assertGt(rebaseTokenMiddleBalance,rebaseTokenStartingBalance);

        // 3. Wrap time once again and check the balance again
        vm.warp(block.timestamp + 1 hours);
        uint256 rebaseTokenEndingBalance = rebaseToken.balanceOf(bob);
        assertGt(rebaseTokenEndingBalance,rebaseTokenMiddleBalance);

        console.log("Starting Balance:",rebaseTokenStartingBalance);
        console.log("Middle Balance:",rebaseTokenMiddleBalance);
        console.log("Ending Balance:",rebaseTokenEndingBalance);

        //This will fail as we have a slight precision loss of 1wei when we do the balanceOf a user
        assertApproxEqAbs((rebaseTokenMiddleBalance - rebaseTokenStartingBalance),(rebaseTokenEndingBalance - rebaseTokenMiddleBalance),1 wei);

        vm.stopPrank();
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount,1e5,type(uint96).max);

        vm.startPrank(bob);

        // 1. Deposit 
        vm.deal(bob,amount);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.balanceOf(bob),amount);

        // 2. redeem
        vault.redeem(type(uint256).max);
        assertEq(rebaseToken.balanceOf(bob),0);
        assertEq(address(bob).balance,amount);

        vm.stopPrank();
    }

    function testRedeemAfterTimeHasPassed(uint256 amount,uint256 time) external {
        amount = bound(amount,1e5,type(uint96).max);
        time = bound(time,1000,type(uint96).max);

        // 1.Deposit
        vm.prank(bob);
        vm.deal(bob,amount);
        vault.deposit{value: amount}();        

        // 2. Pass the time
        vm.warp(block.timestamp + time);

        uint256 balanceAfterSomeTime = rebaseToken.balanceOf(bob);

        // Adding rewards to the vault
        vm.deal(owner,balanceAfterSomeTime - amount);
        vm.prank(owner);
        addRewardsToVault(balanceAfterSomeTime - amount);

        vm.prank(bob);
        vault.redeem(balanceAfterSomeTime);

        uint256 ethBalance = address(bob).balance;

        assertGt(ethBalance,amount);
        assertEq(ethBalance,balanceAfterSomeTime);
    }

    function testTransfer(uint256 amount,uint256 amountToSend) public {
        amount = bound(amount,1e5 + 1e5,type(uint96).max);
        amountToSend = bound(amountToSend,1e5,amount - 1e5);

        // Deposit
        vm.deal(bob,amount);
        vm.prank(bob);
        vault.deposit{value: amount}();

        uint256 bobBalance = rebaseToken.balanceOf(bob);
        uint256 aliceBalance = rebaseToken.balanceOf(alice);

        assertEq(bobBalance,amount);
        assertEq(aliceBalance,0);

        // Owner reduces the interest rates
        vm.prank(owner);
        rebaseToken.setInterestRate(4e10);

        // Transfer
        // Now here the interest rate of alice should be what bob had and not the new one
        vm.prank(bob);
        rebaseToken.transfer(alice,amountToSend);

        uint256 bobBalanceAfterTransfer = rebaseToken.balanceOf(bob);
        uint256 aliceBalanceAfterTransfer = rebaseToken.balanceOf(alice);

        assertEq(bobBalanceAfterTransfer,bobBalance - amountToSend);
        assertEq(aliceBalanceAfterTransfer,aliceBalance + amountToSend);
        
        // Check the interest rates of users (SHould be same)
        assertEq(rebaseToken.getUserInterestRate(alice),5e10);
    }

    function testCannotSetInterestRate(uint256 newInterestRate) public {
        vm.prank(bob);
        // New thing partial revert
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterestRate(newInterestRate);
    }

    function testCannotCallMintAndBurn() public {
        vm.prank(bob);
        vm.expectPartialRevert((IAccessControl.AccessControlUnauthorizedAccount.selector));
        rebaseToken.mint(bob,100,rebaseToken.getUserInterestRate(bob));

        vm.prank(bob);
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.burn(bob,100);
    }

    function testGetThePrincipalAmount(uint256 amount) public {
        amount = bound(amount,1e5,type(uint96).max);
        vm.deal(bob,amount);

        vm.prank(bob);
        vault.deposit{value: amount}();
        assertEq(rebaseToken.principleBalanceOf(bob),amount);

        // Check the balance is same after some time also
        vm.warp(block.timestamp + 1 hours);
        assertEq(rebaseToken.principleBalanceOf(bob),amount);
    }

    function testGetAddressOfRebaseToken() public view {
        assertEq(vault.getTheAddressOfRebaseToken(),address(rebaseToken));
    }

    function testInterestRatesCanOnlyDecrease(uint256 newInterestRate) public {
        newInterestRate = bound(newInterestRate,rebaseToken.getInterestRateOfContract() + 1,type(uint96).max);
        vm.prank(owner);
        vm.expectPartialRevert(RebaseToken.RebaseToken__TheInterestRateCanOnlyDecrease.selector);
        rebaseToken.setInterestRate(newInterestRate);
    }

    
}
