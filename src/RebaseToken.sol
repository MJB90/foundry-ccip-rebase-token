// SPDX-License-Identifier: MIT

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title RebaseToken
 * @author Manas
 * @notice This is a cross chain rebase token that incentivizes users to deposit into a valut and gain interest.
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of deposit.
 */
contract RebaseToken is ERC20, Ownable, AccessControl {
    error RebaseToken_InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    //constants
    uint256 private constant INTEREST_RATE_PRECISION = 1e18; // Precision for interest rate calculations
    bytes32 private constant MINT_AND_BURN_ROLE = keccak256("MINT_AND_BURN_ROLE"); // Role for minting and burning tokens

    // State variables
    uint256 private s_interestRate = 5e10; // The global interest rate for the token
    mapping(address => uint256) private s_userInterestRate; // User specific interest rate
    mapping(address => uint256) private s_userLastUpdatedTimeStamp;

    event InterestRateChanged(uint256 newInterestRate);

    constructor() ERC20("RebaseToken", "RBT") Ownable(msg.sender) {}

    function grantMintAndBurnRole(address _account) external onlyOwner {
        // Grant the mint and burn role to an account
        _grantRole(MINT_AND_BURN_ROLE, _account);
    }

    function setInterstRate(uint256 _interestRate) external onlyOwner {
        // This function can be used to set the interest rate
        // The interest rate can only decrease
        // Implement the logic to set the interest rate
        if (s_interestRate < _interestRate) {
            revert RebaseToken_InterestRateCanOnlyDecrease(s_interestRate, _interestRate);
        }
        s_interestRate = _interestRate;
        emit InterestRateChanged(s_interestRate);
    }

    function mint(address _to, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate; // Set the user's interest rate to the global interest rate at the time of minting
        _mint(_to, _amount);
    }

    function burn(address _from, uint256 _amount) external onlyRole(MINT_AND_BURN_ROLE) {
        if (_amount == type(uint256).max) {
            // If the amount is max, burn the entire balance of the user
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principal balance of the user (the number of tokens that have actually been minted to the user)
        // multiply the principal balance by the interest rate that has accmulated in the time the balance has been last updated
        return super.balanceOf(_user) * _calculateUserAccmulatedInterestSinceLastUpdate(_user) / INTEREST_RATE_PRECISION;
    }

    function transfer(address _recipient, uint256 _amount) public override returns (bool) {
        // Before transferring, mint the accrued interest to the user
        _mintAccruedInterest(msg.sender);
        _mintAccruedInterest(_recipient);

        if (_amount == type(uint256).max) {
            // If the amount is max, transfer the entire balance of the user
            _amount = balanceOf(msg.sender);
        }

        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[msg.sender]; // Set the recipient's interest rate to the sender's interest rate
        }
        // Call the super transfer function
        return super.transfer(_recipient, _amount);
    }

    function transferFrom(address _sender, address _recipient, uint256 _amount) public override returns (bool) {
        // Before transferring, mint the accrued interest to the user
        _mintAccruedInterest(_sender);
        _mintAccruedInterest(_recipient);

        if (_amount == type(uint256).max) {
            // If the amount is max, transfer the entire balance of the user
            _amount = balanceOf(_sender);
        }

        if (balanceOf(_recipient) == 0) {
            s_userInterestRate[_recipient] = s_userInterestRate[_sender]; // Set the recipient's interest rate to the sender's interest rate
        }
        // Call the super transferFrom function
        return super.transferFrom(_sender, _recipient, _amount);
    }

    function _mintAccruedInterest(address _user) internal {
        //1. find current balance of rebase token that have already been minted to the user
        uint256 previousPrincipalBalance = super.balanceOf(_user);
        //2. calculate their current balance including any interest --> balanceOf
        uint256 currentBalance = balanceOf(_user);
        //3. calculate the number of additional tokens that needs to be minted to the user --> 2 - 1
        uint256 balanceIncreased = currentBalance - previousPrincipalBalance;
        // call _mint to mint the tokens to the user
        // set the last updated time stamp for the user
        s_userLastUpdatedTimeStamp[_user] = block.timestamp;
        if (balanceIncreased > 0) {
            _mint(_user, balanceIncreased);
        }
    }

    function _calculateUserAccmulatedInterestSinceLastUpdate(address _user) internal view returns (uint256) {
        // Calculate the interest rate that has accmulated since the last time the user balance was updated
        uint256 timeSinceLastUpdate = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        uint256 interestRate = s_userInterestRate[_user];
        return INTEREST_RATE_PRECISION + (interestRate * timeSinceLastUpdate);
    }

    function getGlobalInterestRate() external view returns (uint256) {
        // Returns the global interest rate
        return s_interestRate;
    }

    function principalBalanceOf(address _user) external view returns (uint256) {
        // Returns the principal balance of the user (the number of tokens that have actually been minted to the user)
        return super.balanceOf(_user);
    }

    function getUserInterestRate(address _user) external view returns (uint256) {
        // Returns the user specific interest rate
        return s_userInterestRate[_user];
    }
}
