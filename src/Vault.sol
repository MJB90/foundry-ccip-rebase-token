//SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {IRebaseToken} from "./interfaces/IRebaseToken.sol";

contract Vault {
    IRebaseToken private immutable i_rebaseToken;

    event Deposit(address indexed user, uint256 amount);
    event Redeem(address indexed user, uint256 amount);

    error Vault_Redeem_FailedToSendEther();

    constructor(IRebaseToken _rebaseToken) {
        // Initialize the vault contract
        i_rebaseToken = _rebaseToken;
    }

    receive() external payable {
        // Receive function to accept Ether deposits
    }

    function deposit() external payable {
        // we need to use the amount of ETH the user has sent to mint tokens to the user
        i_rebaseToken.mint(msg.sender, msg.value);
        emit Deposit(msg.sender, msg.value);
    }

    function redeem(uint256 _amount) external {
        i_rebaseToken.burn(msg.sender, _amount);
        (bool success,) = payable(msg.sender).call{value: _amount}(""); // Send the equivalent amount of ETH back to the user
        if (!success) {
            revert Vault_Redeem_FailedToSendEther();
        }
        emit Redeem(msg.sender, _amount);
    }

    function getRebaseTokenAddress() external view returns (address) {
        // Returns the address of the rebase token
        return address(i_rebaseToken);
    }
}
