//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {RebaseToken} from "../src/RebaseToken.sol";
import {Vault} from "../src/Vault.sol";
import {IRebaseToken} from "../src/interfaces/IRebaseToken.sol";

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
}
