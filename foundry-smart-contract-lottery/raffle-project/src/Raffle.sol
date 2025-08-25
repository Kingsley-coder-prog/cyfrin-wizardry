// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
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

// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title Sample Raffle Contract
 * @author Ifeanyi Nwankwo
 * @notice Contract is for creating a sample raffle
 * @dev This implements Chainlink VRFv2.5
 */
contract Raffle {
    /* Errors */
    error Raffle__SendMoreToEnterRaffle();

    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    /* Events */
    Event RaffleEntered(address indexed player);

    constructor(uint256 entranceFee) {
        i_entranceFee = entranceFee;
    }

    function enterRaffle() public {
        // require(msg.value >= i_entranceFee, "Not Enough ETH sent!");
        // require(msg.value >= i_entranceFee, SendMoreToEnterRaffle());
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMoreToEnterRaffle();
        }
        s_players.push(payable(msg.sender));
        //1. Makes migration easier
        //2. Makes frontend "indexing" easier
        emit RaffleEntered(msg.sender);
    }

    function pickWinner() public {}

    // Getter Functions
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
