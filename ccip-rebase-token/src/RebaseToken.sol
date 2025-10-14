// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/*
* @title RebaseToken
* @author Ifeanyi Nwankwo
* @notice This is a cross-chain rebase token that incentivises users to deposit into a vault
* @notice Each user will have their own interest rate that is the global interest rate at the time of depositing.
*/
contract RebaseToken is ERC20 {
    error RebaseToken__InterestRateCanOnlyDecrease(uint256 oldInterestRate, uint256 newInterestRate);
    
    uint256 private constant PRECISION_FACTOR = 1e18;
    uint256 private s_interestRate = 5e10;
    mapping (address => uint256) private s_userInterestRate;
    mapping (address => uint256) private s_userLastUpdatedTimestamp;

    event InterestRateSet(uint256 newInterestRate);

    constructor() ERC20("Rebase Token", "RBT") {}

    /*
    * @notice Set the interest rate in the contract
    * @param _newInterestRate The new interest rate to set
    * @dev The interest rate can only decrease
    */
    function setInterestRate(uint256 _newInterestRate) external {
        if (_newInterestRate < s_interestRate) {
            revert RebaseToken__InterestRateCanOnlyDecrease(s_interestRate, _newInterestRate);
        }
        s_interestRate = _newInterestRate;
        emit InterestRateSet(_newInterestRate);
    }

    /**
     * @notice Mint the user tokens when they deposit into the vault
     * @param _to The user to mint the token to
     * @param _amount amount of token to mint
     */
    function mint(address _to, uint256 _amount) external {
        _mintAccruedInterest(_to);
        s_userInterestRate[_to] = s_interestRate;
        _mint(_to, _amount);
    }

    /**
     * @notice Burn the user tokens when they withdraw from the vault
     * @param _from The user to burn the token from
     * @param _amount amount of token to burn
     */
    function burn(address _from, uint256 _amount) external {
        if (_amount == type(uint256).max) {
            _amount = balanceOf(_from);
        }
        _mintAccruedInterest(_from);
        _burn(_from, _amount);
    }

    /**
     * @dev See {IERC20-balanceOf}
     *  calculate the balance for the user including the interest that has accumulated since the last update 
     * (principle balance) + some interest that has accrued
     * @param _user The user to calculate the balance for
     * @return The balance of the user including the interest that has accumulated since the last update
     */
    function balanceOf(address _user) public view override returns (uint256) {
        // get the current principle balance of the user (the number of token that have actually been minted to the user)
        // multiply the principle balance by the interest that has accumulated in the time since the balance
        return super.balanceOf(_user) * _calculateUserAccumulatedInterestSinceLastUpdate(_user);
    }

    /**
     * @notice Calculate the interest that has accumulated since the last update
     * @param _user The user to calculate the interest accumulated for
     * @return linearInterest The interest that has accumulated since the last update
     */
    function _calculateUserAccumulatedInterestSinceLastUpdate(address _user) internal view returns (uint256 linearInterest) {
        // calculate the interest that has accumulated since the last update
        // this is going to be linear growth with time
        // 1. calculate the time since the last update
        // 2. calculate the amount of linear growth
        // (principal amount) + principal amount * (user interest rate * time elapsed);
        // principal amount(1 + (user interest rate * time elapsed))
        uint256 timeElapsed = block.timestamp - s_userLastUpdatedTimestamp[_user];
        linearInterest = PRECISION_FACTOR + (s_userInterestRate[_user] * timeElapsed);

    }

    /**
     * @notice Mint the accrued interest to the user since the last time they interacted with the protocol (e.g, burn, mint, transfer)
     * @param _user The user to mint the accrued interest to
     */
    function _mintAccruedInterest(address _user) internal {
        // 1. find their current balance of rebase tokens that have been minted to the user
        uint256 previousPrincipleBalance = super.balanceOf(_user);
        // 2. calculate their current balance including any interest -> balanceOf
        uint256 currentBalance = balanceOf(_user);
        // calculate the number of tokens that need to be minted to the user -> 2 - 1
        uint256 balanceIncrease = currentBalance - previousPrincipleBalance;
        // set the users last updated timestamp
        s_userLastUpdatedTimestamp[_user] = block.timestamp;
        _mint(_user, balanceIncrease);
    }

    /*
    * @notice Get the interest rate for the user
    * @param _user The user to get the interest rate for
    * @return The interest rate for the user
    */
    function getUserInterestRate(address _user) external view returns(uint256) {
        return s_userInterestRate[_user];
    }
}