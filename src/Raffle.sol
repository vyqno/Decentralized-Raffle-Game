// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Decentralized Raffle Game
 * @author vyqno (Hitesh)
 * @notice This contract implements a provably fair raffle system using Chainlink VRF 2.5
 * @dev Integrates with Chainlink VRF for randomness and Automation for autonomous upkeep
 *
 * Features:
 * - Players enter by paying an entrance fee
 * - Automated winner selection using Chainlink VRF
 * - Chainlink Automation triggers winner selection
 * - Winner receives entire prize pool
 * - Owner can reset or manage raffle state
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Represents the current state of the raffle
     * @dev OPEN: Accepting entries | CALCULATING: Selecting winner | CLOSED: Not accepting entries
     */
    enum RaffleGameState {
        OPEN,
        CALCULATING,
        CLOSED
    }

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error Raffle__NotOwner();
    error Raffle__NotEnoughETHsent();
    error Raffle__GameAlreadyStarted();
    error Raffle__GameNotOpen();
    error Raffle__AlreadyEntered();
    error Raffle__NotEnoughPlayers();
    error Raffle__TransferFailed();
    error Raffle__DirectETHNotAllowed();
    error Raffle__UpkeepNotNeeded(uint256 currentBalance, uint256 numPlayers, RaffleGameState state);

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Emitted when a player successfully enters the raffle
     * @param player Address of the player who entered
     */
    event RaffleEntered(address indexed player);

    /**
     * @notice Emitted when winner selection is initiated
     * @param requestId VRF request ID for tracking randomness request
     */
    event RaffleWinnerRequested(uint256 indexed requestId);

    /**
     * @notice Emitted when winner is selected and prize is distributed
     * @param winner Address of the winning player
     * @param prize Amount of ETH won
     */
    event RaffleWinnerPicked(address indexed winner, uint256 prize);

    /**
     * @notice Emitted when the raffle is reset by owner
     * @param playerCount Number of players that were removed
     */
    event RaffleReset(uint256 playerCount);

    /*//////////////////////////////////////////////////////////////
                          IMMUTABLE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Minimum ETH required to enter the raffle
    uint256 private immutable i_entranceFee;

    /// @notice Time interval between raffle rounds (in seconds)
    uint256 private immutable i_interval;

    /// @notice Owner address with administrative privileges
    address private immutable i_owner;

    /// @notice Chainlink VRF gas lane key hash
    bytes32 private immutable i_gasKeyHash;

    /// @notice Chainlink VRF subscription ID
    uint256 private immutable i_subscriptionId;

    /// @notice Gas limit for VRF callback function
    uint32 private immutable i_callbackGasLimit;

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    /// @notice Timestamp of last raffle round completion
    uint256 private s_lastTimeStamp;

    /// @notice Address of most recent winner
    address private s_recentWinner;

    /// @notice Array of current raffle participants
    address payable[] private s_players;

    /// @notice Mapping to track if an address has entered current round
    mapping(address => bool) private s_hasEntered;

    /// @notice Current state of the raffle game
    RaffleGameState private s_raffleGameState;

    /*//////////////////////////////////////////////////////////////
                              CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Number of block confirmations for VRF request
    uint16 private constant REQUEST_CONFIRMATIONS = 3;

    /// @notice Number of random words to request from VRF
    uint32 private constant NUM_WORDS = 1;

    /// @notice Minimum number of players required to start raffle
    uint256 private constant MIN_PLAYERS = 3;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Initializes the raffle contract with configuration parameters
     * @param entranceFee Minimum ETH required to enter
     * @param interval Time between raffle rounds in seconds
     * @param owner Address that will own and manage the contract
     * @param vrfCoordinator Chainlink VRF Coordinator address
     * @param gasKeyHash Chainlink VRF gas lane identifier
     * @param subscriptionId Chainlink VRF subscription ID
     * @param callbackGasLimit Gas limit for fulfillRandomWords callback
     */
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

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricts function access to contract owner only
     */
    modifier onlyTheOwner() {
        if (i_owner != msg.sender) revert Raffle__NotOwner();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                          EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Allows a player to enter the raffle by paying entrance fee
     * @dev Player must send exact or more than entrance fee
     * @dev Player can only enter once per round
     * @dev Raffle must be in OPEN state
     */
    function enterRaffleGame() external payable {
        if (msg.value < i_entranceFee) revert Raffle__NotEnoughETHsent();
        if (s_raffleGameState != RaffleGameState.OPEN) revert Raffle__GameNotOpen();
        if (s_hasEntered[msg.sender]) revert Raffle__AlreadyEntered();

        s_players.push(payable(msg.sender));
        s_hasEntered[msg.sender] = true;

        emit RaffleEntered(msg.sender);
    }

    /**
     * @notice Checks if upkeep is needed (called by Chainlink Automation)
     * @dev Upkeep is needed when:
     *      - Raffle is OPEN
     *      - Enough time has passed since last round
     *      - At least MIN_PLAYERS have entered
     *      - Contract has balance
     * @return upkeepNeeded True if performUpkeep should be called
     * @return performData Additional data (not used in this implementation)
     */
    function checkUpkeep(bytes memory /* checkData */ )
        public
        view
        returns (bool upkeepNeeded, bytes memory /* performData */ )
    {
        bool isGameOpen = RaffleGameState.OPEN == s_raffleGameState;
        bool hasEnoughTimePassed = ((block.timestamp - s_lastTimeStamp) > i_interval);
        bool isEnoughPlayersEntered = s_players.length >= MIN_PLAYERS;
        bool hasBalance = address(this).balance > 0;

        upkeepNeeded = (isGameOpen && hasEnoughTimePassed && isEnoughPlayersEntered && hasBalance);
        return (upkeepNeeded, bytes(""));
    }

    /**
     * @notice Initiates winner selection process (called by Chainlink Automation)
     * @dev Requests random words from Chainlink VRF
     * @dev Sets raffle state to CALCULATING
     */
    function performUpkeep(bytes calldata /* performData */ ) external {
        (bool upkeepNeeded,) = checkUpkeep(bytes(""));
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(address(this).balance, s_players.length, s_raffleGameState);
        }

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

    /**
     * @notice Resets the raffle by clearing all players (owner only)
     * @dev Clears player array and entry tracking mapping
     * @dev Does not change raffle state
     */
    function resetRaffleGame() external onlyTheOwner {
        uint256 playerCount = s_players.length;

        for (uint256 i = 0; i < playerCount; i++) {
            s_hasEntered[s_players[i]] = false;
        }
        delete s_players;

        emit RaffleReset(playerCount);
    }

    /**
     * @notice Manually starts the raffle (owner only)
     * @dev Changes state from CLOSED to OPEN
     * @dev Reverts if raffle is already started
     */
    function startRaffle() external onlyOwner {
        if (s_raffleGameState != RaffleGameState.CLOSED) {
            revert Raffle__GameAlreadyStarted();
        }
        s_raffleGameState = RaffleGameState.OPEN;
    }

    /**
     * @notice Prevents direct ETH transfers to contract
     * @dev Players must use enterRaffleGame() function
     */
    receive() external payable {
        revert Raffle__DirectETHNotAllowed();
    }

    /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Callback function called by VRF Coordinator with random words
     * @dev Selects winner, distributes prize, and resets for next round
     * @param "requestId" VRF request identifier (not used)
     * @param "randomWords"  Array of random values from Chainlink VRF
     */
    function fulfillRandomWords(uint256, /* requestId */ uint256[] calldata randomWords) internal override {
        // Select winner using modulo operation
        uint256 winnerIndex = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[winnerIndex];

        s_recentWinner = recentWinner;
        uint256 prizeAmount = address(this).balance;

        // Reset raffle state for next round
        for (uint256 i = 0; i < s_players.length; i++) {
            s_hasEntered[s_players[i]] = false;
        }
        s_players = new address payable[](0);
        s_raffleGameState = RaffleGameState.OPEN;
        s_lastTimeStamp = block.timestamp;

        emit RaffleWinnerPicked(recentWinner, prizeAmount);

        // Transfer prize to winner
        (bool success,) = recentWinner.call{value: prizeAmount}("");
        if (!success) revert Raffle__TransferFailed();
    }

    /*//////////////////////////////////////////////////////////////
                           GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the entrance fee required to participate
     */
    function getEntranceFee() external view returns (uint256) {
        return i_entranceFee;
    }

    /**
     * @notice Returns the current state of the raffle
     */
    function getRaffleState() external view returns (RaffleGameState) {
        return s_raffleGameState;
    }

    /**
     * @notice Returns the owner address
     */
    function getOwner() external view returns (address) {
        return i_owner;
    }

    /**
     * @notice Returns the time interval between raffle rounds
     */
    function getTimeInterval() external view returns (uint256) {
        return i_interval;
    }

    /**
     * @notice Returns the number of players currently entered
     */
    function getPlayersCount() external view returns (uint256) {
        return s_players.length;
    }

    /**
     * @notice Returns the address of a player at specified index
     * @param index Position in players array
     */
    function getPlayer(uint256 index) external view returns (address) {
        return s_players[index];
    }

    /**
     * @notice Returns array of all current players
     */
    function getAllPlayers() external view returns (address payable[] memory) {
        return s_players;
    }

    /**
     * @notice Returns the address of most recent winner
     */
    function getRecentWinner() external view returns (address) {
        return s_recentWinner;
    }

    /**
     * @notice Returns the timestamp of last raffle completion
     */
    function getLastTimeStamp() external view returns (uint256) {
        return s_lastTimeStamp;
    }

    /**
     * @notice Checks if a specific player has entered current round
     * @param player Address to check
     */
    function hasPlayerEntered(address player) external view returns (bool) {
        return s_hasEntered[player];
    }

    /**
     * @notice Returns the minimum number of players required
     */
    function getMinimumPlayers() external pure returns (uint256) {
        return MIN_PLAYERS;
    }

    /**
     * @notice Returns the current prize pool amount
     */
    function getPrizePool() external view returns (uint256) {
        return address(this).balance;
    }
}
