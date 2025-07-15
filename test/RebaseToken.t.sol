//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract RebaseTokenTest is Test {
    RebaseToken private rebaseToken;
    Vault private vault;

    address public owner = makeAddr("owner");
    address public user = makeAddr("user");

    function setUp() public {
        vm.startPrank(owner);
        vm.deal(owner, 1 ether); // Give owner some ether to deploy contracts
        // Setup code can be added here if needed
        rebaseToken = new RebaseToken();
        vault = new Vault(IRebaseToken(address(rebaseToken)));
        rebaseToken.grantMintAndBurnRole(address(vault));
        (bool success,) = payable(address(vault)).call{value: 1 ether}(""); // Send some ether to the vault
        if (!success) {
            revert("Failed to send ether to vault");
        }
        vm.stopPrank();
    }

    function addRewardsToVault(uint256 rewardAmount) public {
        (bool success,) = payable(address(vault)).call{value: rewardAmount}(""); // Send some ether to the vault
        if (!success) {
            revert("Failed to send ether to vault");
        }
    }

    function testDepositLinear(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max); // Bound the amount to a reasonable range
        //1. deposit
        vm.startPrank(user);
        vm.deal(user, amount); // Give user some ether
        vault.deposit{value: amount}(); // User deposits ether into the vault
        //2. check our rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("startBalance: %s", startBalance);
        assertEq(startBalance, amount); // Check if the balance is equal to the deposited amount
        //3. warp the time and check the balance again
        vm.warp(block.timestamp + 1 hours); // Warp the time by 1 hour
        uint256 midBalance = rebaseToken.balanceOf(user);
        assertGt(midBalance, startBalance); // Check if the balance has increased due to interest accrual
        //4. warp the time again and check the balance again
        vm.warp(block.timestamp + 1 hours); // Warp the time by another hour
        uint256 endBalance = rebaseToken.balanceOf(user);
        assertGt(endBalance, midBalance); // Check if the balance has increased again due to interest accrual

        assertApproxEqAbs(endBalance - midBalance, midBalance - startBalance, 1); // Check if the increase in balance is linear
    }

    function testRedeemStraightAway(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max); // Bound the amount to a reasonable range
        //1. deposit
        vm.startPrank(user);
        vm.deal(user, amount + 1); // Give user some ether
        vault.deposit{value: amount}(); // User deposits ether into the vault
        //2. check our rebase token balance
        uint256 startBalance = rebaseToken.balanceOf(user);
        console.log("startBalance: %s", startBalance);
        assertEq(startBalance, amount); // Check if the balance is equal to the deposited amount
        //3. redeem straight away
        vault.redeem(type(uint256).max); // User redeems their tokens for ether
        assertEq(rebaseToken.balanceOf(user), 0); // Check if the user's rebase token balance is zero
        assertApproxEqAbs(address(user).balance, amount, 1); // Check if the ether balance is equal to the deposited amount

        vm.stopPrank();
    }

    function testRedeemAfterTimePassed(uint256 depositAmount, uint256 time) public {
        time = bound(time, 1000, type(uint96).max); // Bound the time to a reasonable range
        depositAmount = bound(depositAmount, 1e5, type(uint96).max); // Bound the amount to a reasonable range

        vm.deal(user, depositAmount); // Give user some ether
        vm.prank(user);
        vault.deposit{value: depositAmount}(); // User deposits ether into the vault

        vm.warp(block.timestamp + time); // Warp the time by the specified amount
        uint256 balance = rebaseToken.balanceOf(user);

        //Add rewards to the vault
        vm.prank(owner);
        vm.deal(owner, balance - depositAmount); // Give owner some ether to add as rewards
        addRewardsToVault(balance - depositAmount); // Add some ether to the vault as rewards

        vm.prank(user);
        vault.redeem(type(uint256).max); // User redeems their tokens for ether
        uint256 etherBalance = address(user).balance;

        assertEq(etherBalance, balance);
        assertGt(etherBalance, depositAmount);
    }

    function testTransfer(uint256 amount, uint256 amountToSend) public {
        amount = bound(amount, 1e5 + 1e5, type(uint96).max);
        amountToSend = bound(amountToSend, 1e5, amount - 1e5);

        vm.deal(user, amount); // Give user some ether
        vm.prank(user);
        vault.deposit{value: amount}(); // User deposits ether into the vault

        address user2 = makeAddr("user2");
        uint256 userBalance = rebaseToken.balanceOf(user);
        uint256 user2BalanceBefore = rebaseToken.balanceOf(user2);

        assertEq(userBalance, amount); // Check if the balance is equal to the deposited amount
        assertEq(user2BalanceBefore, 0); // Check if the user2's balance

        vm.prank(owner);
        rebaseToken.setInterstRate(4e10);

        vm.prank(user);
        rebaseToken.transfer(user2, amountToSend); // User transfers some tokens to user
        uint256 userBalanceAfter = rebaseToken.balanceOf(user);
        uint256 user2BalanceAfter = rebaseToken.balanceOf(user2);

        assertEq(userBalanceAfter, userBalance - amountToSend); // Check if the user's balance is reduced by the transferred amount
        assertEq(user2BalanceAfter, user2BalanceBefore + amountToSend); // Check

        assertEq(rebaseToken.getUserInterestRate(user), 5e10); // Check if the interest rate is set correctly
    }

    function testCannotSetInterestRateByNonOwner(uint256 newInterestRate) public {
        vm.prank(user);
        vm.expectPartialRevert(Ownable.OwnableUnauthorizedAccount.selector);
        rebaseToken.setInterstRate(newInterestRate); // Non-owner tries to set the interest rate
    }

    function testCannotMintAndBurn() public {
        vm.prank(user);
        uint256 interestRate = rebaseToken.getGlobalInterestRate();
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.mint(user, 1e18, interestRate); // Non-owner tries to mint
        vm.expectPartialRevert(IAccessControl.AccessControlUnauthorizedAccount.selector);
        rebaseToken.burn(user, 1e18); // Non-owner tries to burn
    }

    function testGetPrincipalBalance(uint256 amount) public {
        amount = bound(amount, 1e5, type(uint96).max); // Bound the amount to a reasonable range
        vm.deal(user, amount); // Give user some ether
        vm.prank(user);
        vault.deposit{value: amount}(); // User deposits ether into the vault
        uint256 principalBalance = rebaseToken.principalBalanceOf(user);
        assertEq(principalBalance, amount); // Check if the principal balance is equal to the
    }

    function testGetRebaseTokenAddress() public view {
        address rebaseTokenAddress = vault.getRebaseTokenAddress();
        assertEq(rebaseTokenAddress, address(rebaseToken)); // Check if the rebase token address is correct
    }

    function testInterestRateCanOnlyDecrease(uint256 newInterestRate) public {
        newInterestRate = bound(newInterestRate, rebaseToken.getGlobalInterestRate(), type(uint96).max); // Bound the interest rate to a reasonable range
        vm.prank(owner);
        vm.expectPartialRevert(RebaseToken.RebaseToken_InterestRateCanOnlyDecrease.selector);
        rebaseToken.setInterstRate(newInterestRate); // Owner tries to set the interest
    }
}
