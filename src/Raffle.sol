// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

/**
 * @title  Decentralized Raffle Game
 * @author vyqno (Hitesh)
 * @notice This is a raffle contract which uses Chainlink VRF 2.5 to perform fair Raffle game among the particpants.
 */
enum RaffleGameState {
    OPEN,
    CALCULATING,
    CLOSED
}

contract Raffle {
    error Raffle__NotOwner();
    error Raffle__NotEnoughETHsent();
    error Raffle__GameAlredyStarted();
    error Raffle__GameNotOpen();
    error Raffle__AlreadyEntered();
    error Raffle__NotEnoughPlayers();

    event RaffleEntered(address newPlayer);

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    address private immutable i_owner;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    address payable[] private s_players;
    mapping(address => bool) private allowedUsers;
    RaffleGameState private s_raffleGameState;

    constructor(uint256 entranceFee, uint256 interval, address owner) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_owner = owner;
        s_lastTimeStamp = block.timestamp;
        s_raffleGameState = RaffleGameState.OPEN;
    }

    modifier onlyOwner() {
        if(i_owner == msg.sender) revert Raffle__NotOwner();
        _;
    }

    function enterRaffleGame() public payable {
        if (msg.value < i_entranceFee) revert Raffle__NotEnoughETHsent();
        if (s_raffleGameState != RaffleGameState.OPEN) revert Raffle__GameNotOpen();
        if (allowedUsers[msg.sender]) revert Raffle__AlreadyEntered();

        s_players.push(payable(msg.sender));
        allowedUsers[msg.sender] = true;

        emit RaffleEntered(msg.sender);
    }

    function pickWinner() public {
        s_raffleGameState = RaffleGameState.CALCULATING;
    }

    function resetRaffleGame() external onlyOwner {
        delete s_players;
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleGameState) {
        return s_raffleGameState;
    }

    function getOwner() external view returns(address){
        return i_owner;
    }

    function getTimeIntervalOfRaffleGame() external view returns (uint256) {
        return i_interval;
    }

    function getPlayersCount() external view returns (uint256) {
        return s_players.length;
    }
}
