// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {
    VRFCoordinatorV2Interface
} from "@chainlink/contracts/src/v0.8/vrf/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/vrf/VRFConsumerBaseV2.sol";

// Layout of the contract file:
//   version
//   imports
//   errors
//   interfaces, libraries, contract

// Inside Contract:
//   Type declarations
//   State variables
//   Events
//   Errors
//   Modifiers
//   Functions

// Layout of Functions:
//   constructor
//   receive function (if exists)
//   fallback function (if exists)
//   external
//   public
//   internal
//   private
//   view & pure functions

/**
 * @title A sample Raffle Contract
 * @author Jimmy Chu
 * @notice This contract is for creating a sample raffle
 * @dev it implements Chainlink VRF v2.5 and Chainlink Automation
 */
contract Raffle is VRFConsumerBaseV2 {
    // storage
    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;

    // Chainlink VRF related variables
    VRFCoordinatorV2Interface immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint64 private immutable i_subscriptionId;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private immutable i_callbackGasLimit;
    uint32 private constant NUM_WORDS = 1;

    // errors
    error Raffle__NotEnoughEthSent();

    // events
    event EnteredRaffle(address indexed player);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;

        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_gasLane = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
    }

    function enterRaffle() public payable {
        if (msg.value < i_entranceFee) revert Raffle__NotEnoughEthSent();
        s_players.push(payable(msg.sender));

        emit EnteredRaffle(msg.sender);
    }

    function pickWinner() public {
        if (block.timestamp - s_lastTimeStamp < i_interval) revert();

        i_vrfCoordinator.requestRandomWords(
            i_gasLane, i_subscriptionId, REQUEST_CONFIRMATIONS, i_callbackGasLimit, NUM_WORDS
        );
    }

    function fulfillRandomWords(
        uint256 requiestId,
        uint256[] memory randomWords
    ) internal override {}

    /**
     * Getter Function
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }
}
