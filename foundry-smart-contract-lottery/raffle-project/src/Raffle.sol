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
    // @dev Internal is the duration of the lottery in seconds
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;

    /* Events */
    Event RaffleEntered(address indexed player);

    constructor(uint256 entranceFee, uint256 interval) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffle() external {
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

    function pickWinner() external {
        // check to see if enough time has passed
       if ((block.timestamp - s_lastTimeStamp ) < i_interval) {
        revert();
       };
    }

    // Getter Functions
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
