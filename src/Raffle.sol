// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {AutomationCompatibleInterface} from
    "@chainlink/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";

/**
 * /**
 * @title  Decentralized Raffle Game
 * @author vyqno (Hitesh)
 * @notice This is a raffle contract which uses Chainlink VRF 2.5 to perform fair Raffle game among the particpants.
 */
enum RaffleGameState {
    OPEN,
    CALCULATING,
    CLOSED
}

contract Raffle is VRFConsumerBaseV2Plus {
    error Raffle__NotOwner();
    error Raffle__NotEnoughETHsent();
    error Raffle__GameAlredyStarted();
    error Raffle__GameNotOpen();
    error Raffle__AlreadyEntered();
    error Raffle__NotEnoughPlayers();
    error Raffle__TransferFailed();
    error Raffle__DirectETHNotAllowed();
    error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, RaffleGameState state);

    event RaffleEntered(address indexed player);
    event RaffleWinnerRequested(uint256 indexed requestId);
    event RaffleWinnerPicked(address indexed winner, uint256 prize);

    event RaffleReset(uint256 playerCount);

    uint256 private immutable i_entranceFee;
    uint256 private immutable i_interval;
    address private immutable i_owner;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    address payable[] private s_players;
    mapping(address => bool) private s_hasEntered;
    RaffleGameState private s_raffleGameState;

    // VRFConsumerBase Variables
    bytes32 private immutable i_gasKeyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private constant MIN_PLAYERS = 3;

    bytes extraArgs;

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address owner,
        address vrfCoordinator,
        bytes32 gasKeyHash,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        i_owner = owner;
        i_gasKeyHash = gasKeyHash;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = callbackGasLimit;
        s_lastTimeStamp = block.timestamp;
        s_raffleGameState = RaffleGameState.OPEN;
    }

    modifier onlyOwnerCan() {
        if (i_owner != msg.sender) revert Raffle__NotOwner();
        _;
    }

    function enterRaffleGame() public payable {
        if (msg.value < i_entranceFee) revert Raffle__NotEnoughETHsent();
        if (s_raffleGameState != RaffleGameState.OPEN) revert Raffle__GameNotOpen();
        if (s_hasEntered[msg.sender]) revert Raffle__AlreadyEntered();

        s_players.push(payable(msg.sender));
        s_hasEntered[msg.sender] = true;

        emit RaffleEntered(msg.sender);
    }

    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool isGameOpen = RaffleGameState.OPEN == s_raffleGameState;
        bool hasEnoughTimePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool isEnoughPlayersEnteredGame = s_players.length > MIN_PLAYERS;
        bool hasBalanceEnough = address(this).balance > 0;

        upkeepNeeded = (isGameOpen && hasEnoughTimePassed && isEnoughPlayersEnteredGame && hasBalanceEnough);
        return (upkeepNeeded, bytes(""));
    }

    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep(bytes(""));
        if (!upkeepNeeded) revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, s_raffleGameState);

        s_raffleGameState = RaffleGameState.CALCULATING;

        VRFV2PlusClient.RandomWordsRequest memory req = VRFV2PlusClient.RandomWordsRequest({
            keyHash: i_gasKeyHash,
            subId: i_subscriptionId,
            requestConfirmations: REQUEST_CONFIRMATIONS,
            callbackGasLimit: i_callbackGasLimit,
            numWords: NUM_WORDS,
            extraArgs: VRFV2PlusClient._argsToBytes(VRFV2PlusClient.ExtraArgsV1({nativePayment: false}))
        });
        uint256 requestId = s_vrfCoordinator.requestRandomWords(req);
        emit RaffleWinnerRequested(requestId);
    }

    function resetRaffleGame() external onlyOwner {
        uint256 playerCount = s_players.length;
        for (uint256 i = 0; i < playerCount; i++) {
            s_hasEntered[s_players[i]] = false;
        }
        delete s_players;

        emit RaffleReset(playerCount);
    }

    receive() external payable {
        revert Raffle__DirectETHNotAllowed();
    }

    function startRaffle() external onlyOwnerCan {
        if (s_raffleGameState != RaffleGameState.CLOSED) revert Raffle__GameAlredyStarted();
        s_raffleGameState = RaffleGameState.OPEN;
    }

    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal override {
        uint256 winnerindex = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[winnerindex];

        s_recentWinner = recentWinner;
        uint256 prizeAmount = address(this).balance;

        s_players = new address payable[](0);
        s_raffleGameState = RaffleGameState.OPEN;
        s_lastTimeStamp = block.timestamp;

        emit RaffleWinnerPicked(recentWinner, prizeAmount);

        (bool success,) = recentWinner.call{value: prizeAmount}("");
        if (!success) revert Raffle__TransferFailed();
    }

    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() external view returns (RaffleGameState) {
        return s_raffleGameState;
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }

    function getTimeIntervalOfRaffleGame() external view returns (uint256) {
        return i_interval;
    }

    function getPlayersCount() external view returns (uint256) {
        return s_players.length;
    }

    function getPlayer(uint256 index) external view returns (address) {
        return s_players[index];
    }

    function getAllPlayers() external view returns (address payable[] memory) {
        return s_players;
    }

    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    function hasPlayerEntered(address player) external view returns (bool) {
        return s_hasEntered[player];
    }
}
