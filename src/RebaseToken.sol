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

/* * @title RebaseToken
 * @author Manas
 * @notice This is a cross chain rebase token that incentivizes users to deposit into a valut and gain interest.
 * @notice The interest rate in the smart contract can only decrease.
 * @notice Each user will have their own interest rate that is the global interest rate at the time of deposit.
 */

contract RebaseToken is ERC20{

    error RebaseToken_InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);

    uint256 private constant INTEREST_RATE_PRECISION = 1e18; // Precision for interest rate calculations
    uint256 private s_interestRate = 5e10; // The global interest rate for the token
    mapping(address => uint256) private s_userInterestRate; // User specific interest rate
    mapping(address => uint256) private s_userLastUpdatedTimeStamp;
    event InterestRateChanged(uint256 newInterestRate);


    constructor() ERC20("RebaseToken", "RBT") {
        
        
    }
    function setInterstRate(uint256 _interestRate) external {
        // This function can be used to set the interest rate
        // The interest rate can only decrease
        // Implement the logic to set the interest rate
        if(s_interestRate < _interestRate) {
            revert RebaseToken_InterestRateCanOnlyDecrease(s_interestRate, _interestRate);
        }
        s_interestRate = _interestRate;
        emit InterestRateChanged(s_interestRate);
    }

    function mint (address _to, uint256 _amount) external{
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate; // Set the user's interest rate to the global interest rate at the time of minting
        _mint(_to, _amount);
    }

    function _mintAccruedInterest(address _user) internal{
        //1. find current balance of rebase token that have already been minted to the user
        //2. calculate their current balance including any interest --> balanceOf
        //3. calculate the number of additional tokens that needs to be minted to the user --> 2 - 1
        // call _mint to mint the tokens to the user
        // set the last updated time stamp for the user
        s_userLastUpdatedTimeStamp[_user] = block.timestamp;

    }

    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principal balance of the user (the number of tokens that have actually been minted to the user)
        // multiply the principal balance by the interest rate that has accmulated in the time the balance has been last updated
        return super.balanceOf(_user) * _calculateUserAccmulatedInterestSinceLastUpdate(_user)/INTEREST_RATE_PRECISION;
        
    }


    function _calculateUserAccmulatedInterestSinceLastUpdate(address _user) internal view returns (uint256) {
        // Calculate the interest rate that has accmulated since the last time the user balance was updated
        uint256 timeSinceLastUpdate = block.timestamp - s_userLastUpdatedTimeStamp[_user];
        uint256 interestRate = s_userInterestRate[_user];
        return INTEREST_RATE_PRECISION + (interestRate * timeSinceLastUpdate);
    }

    function getUserInterestRate(address _user) external view returns (uint256) {
        // Returns the user specific interest rate
        return s_userInterestRate[_user];
    }
}