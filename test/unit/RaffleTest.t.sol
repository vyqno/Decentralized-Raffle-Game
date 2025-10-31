// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "../../test/mocks/VRFCoordinatorV2_5Mock.sol";

/**
 * @title RaffleTest
 * @notice Comprehensive unit tests for Raffle contract
 * @dev Tests all core functionality, edge cases, and failure scenarios
 */
contract RaffleTest is Test {
    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event RaffleEntered(address indexed player);
    event RaffleWinnerRequested(uint256 indexed requestId);
    event RaffleWinnerPicked(address indexed winner, uint256 prize);
    event RaffleReset(uint256 playerCount);

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    address public PLAYER_2 = makeAddr("player2");
    address public PLAYER_3 = makeAddr("player3");
    address public PLAYER_4 = makeAddr("player4");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasKeyHash;
    uint256 subscriptionId;
    uint32 callbackGasLimit;
    address link;
    address owner;

    /*//////////////////////////////////////////////////////////////
                                 SETUP
    //////////////////////////////////////////////////////////////*/

    function setUp() external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();

        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        entranceFee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gasKeyHash = config.gasKeyHash;
        subscriptionId = config.subscriptionId;
        callbackGasLimit = config.callbackGasLimit;
        link = config.link;
        owner = config.account;

        // Fund players
        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
        vm.deal(PLAYER_2, STARTING_PLAYER_BALANCE);
        vm.deal(PLAYER_3, STARTING_PLAYER_BALANCE);
        vm.deal(PLAYER_4, STARTING_PLAYER_BALANCE);
    }

    /*//////////////////////////////////////////////////////////////
                          CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/

    function test_RaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleGameState.OPEN);
    }

    function test_RaffleInitializesWithCorrectEntranceFee() public view {
        assertEq(raffle.getEntranceFee(), entranceFee);
    }

    function test_RaffleInitializesWithCorrectInterval() public view {
        assertEq(raffle.getTimeInterval(), interval);
    }

    function test_RaffleInitializesWithCorrectOwner() public view {
        assertEq(raffle.getOwner(), owner);
    }

    function test_RaffleInitializesWithZeroPlayers() public view {
        assertEq(raffle.getPlayersCount(), 0);
    }

    function test_RaffleInitializesWithMinimumPlayers() public view {
        assertEq(raffle.getMinimumPlayers(), 3);
    }

    /*//////////////////////////////////////////////////////////////
                       ENTER RAFFLE GAME TESTS
    //////////////////////////////////////////////////////////////*/

    function test_EnterRaffleGame_SuccessfulEntry() public {
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();

        assertEq(raffle.getPlayersCount(), 1);
        assertEq(raffle.getPlayer(0), PLAYER);
        assertTrue(raffle.hasPlayerEntered(PLAYER));
    }

    function test_EnterRaffleGame_EmitsEvent() public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();
    }

    function test_EnterRaffleGame_RevertsWhenNotEnoughETH() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughETHsent.selector);
        raffle.enterRaffleGame{value: entranceFee - 1}();
    }

    function test_EnterRaffleGame_RevertsWhenNotEnoughETHWithZero() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughETHsent.selector);
        raffle.enterRaffleGame{value: 0}();
    }

    function test_EnterRaffleGame_AcceptsMoreThanEntranceFee() public {
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee * 2}();

        assertEq(raffle.getPlayersCount(), 1);
        assertEq(address(raffle).balance, entranceFee * 2);
    }

    function test_EnterRaffleGame_RevertsWhenAlreadyEntered() public {
        vm.startPrank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();

        vm.expectRevert(Raffle.Raffle__AlreadyEntered.selector);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.stopPrank();
    }

    function test_EnterRaffleGame_AllowsMultiplePlayers() public {
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();

        vm.prank(PLAYER_2);
        raffle.enterRaffleGame{value: entranceFee}();

        vm.prank(PLAYER_3);
        raffle.enterRaffleGame{value: entranceFee}();

        assertEq(raffle.getPlayersCount(), 3);
    }

    function test_EnterRaffleGame_RevertsWhenRaffleNotOpen() public {
        // Enter with enough players
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.prank(PLAYER_2);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.prank(PLAYER_3);
        raffle.enterRaffleGame{value: entranceFee}();

        // Fast forward time
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Perform upkeep to change state to CALCULATING
        raffle.performUpkeep("");

        // Try to enter while calculating
        vm.prank(PLAYER_4);
        vm.expectRevert(Raffle.Raffle__GameNotOpen.selector);
        raffle.enterRaffleGame{value: entranceFee}();
    }

    /*//////////////////////////////////////////////////////////////
                          CHECK UPKEEP TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CheckUpkeep_ReturnsFalseIfNoBalance() public {
        // Fast forward time
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assertFalse(upkeepNeeded);
    }

    function test_CheckUpkeep_ReturnsFalseIfNotEnoughPlayers() public {
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();

        // Fast forward time
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assertFalse(upkeepNeeded);
    }

    function test_CheckUpkeep_ReturnsFalseIfNotEnoughTimePassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.prank(PLAYER_2);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.prank(PLAYER_3);
        raffle.enterRaffleGame{value: entranceFee}();

        // Don't fast forward time
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assertFalse(upkeepNeeded);
    }

    function test_CheckUpkeep_ReturnsTrueWhenAllConditionsMet() public {
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.prank(PLAYER_2);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.prank(PLAYER_3);
        raffle.enterRaffleGame{value: entranceFee}();

        // Fast forward time
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assertTrue(upkeepNeeded);
    }

    function test_CheckUpkeep_ReturnsFalseIfRaffleNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.prank(PLAYER_2);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.prank(PLAYER_3);
        raffle.enterRaffleGame{value: entranceFee}();

        // Fast forward time
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Perform upkeep
        raffle.performUpkeep("");

        // Check upkeep while calculating
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        assertFalse(upkeepNeeded);
    }

    /*//////////////////////////////////////////////////////////////
                        PERFORM UPKEEP TESTS
    //////////////////////////////////////////////////////////////*/

    function test_PerformUpkeep_CanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.prank(PLAYER_2);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.prank(PLAYER_3);
        raffle.enterRaffleGame{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
        // If it doesn't revert, test passes
    }

    function test_PerformUpkeep_RevertsIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 numPlayers = 0;
        Raffle.RaffleGameState raffleState = raffle.getRaffleState();

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector, currentBalance, numPlayers, raffleState)
        );
        raffle.performUpkeep("");
    }

    function test_PerformUpkeep_UpdatesRaffleStateAndEmitsRequestId() public {
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.prank(PLAYER_2);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.prank(PLAYER_3);
        raffle.enterRaffleGame{value: entranceFee}();

        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // First log is from VRF coordinator, second is from Raffle
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleGameState raffleState = raffle.getRaffleState();

        assert(uint256(requestId) > 0);
        assert(uint256(raffleState) == 1); // CALCULATING
    }

    /*//////////////////////////////////////////////////////////////
                    FULFILL RANDOM WORDS TESTS
    //////////////////////////////////////////////////////////////*/

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.prank(PLAYER_2);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.prank(PLAYER_3);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function test_FulfillRandomWords_CanOnlyBeCalledAfterPerformUpkeep() public raffleEntered {
        vm.expectRevert();
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(0, address(raffle));
    }

    function test_FulfillRandomWords_PicksWinnerResetsAndSendsMoney() public raffleEntered {
        // Additional players
        uint256 additionalEntrants = 3;
        uint256 startingIndex = 4;

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrants; i++) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, STARTING_PLAYER_BALANCE);
            raffle.enterRaffleGame{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance;

        // Perform upkeep
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Get expected winner before fulfillment
        uint256 expectedPrize = address(raffle).balance;

        // Fulfill random words
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // Get actual winner
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleGameState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = expectedPrize;

        assert(recentWinner != address(0));
        assert(uint256(raffleState) == 0); // OPEN
        assert(winnerBalance == STARTING_PLAYER_BALANCE + prize - entranceFee);
        assert(endingTimeStamp > startingTimeStamp);
        assertEq(raffle.getPlayersCount(), 0);
    }

    function test_FulfillRandomWords_EmitsWinnerPickedEvent() public raffleEntered {
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        vm.expectEmit(true, false, false, true, address(raffle));
        emit RaffleWinnerPicked(address(0), 0); // We don't know winner beforehand

        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));
    }

    /*//////////////////////////////////////////////////////////////
                         RESET RAFFLE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_ResetRaffle_OnlyOwnerCanReset() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotOwner.selector);
        raffle.resetRaffleGame();
    }

    function test_ResetRaffle_ResetsPlayersArray() public {
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.prank(PLAYER_2);
        raffle.enterRaffleGame{value: entranceFee}();

        assertEq(raffle.getPlayersCount(), 2);

        vm.prank(owner);
        raffle.resetRaffleGame();

        assertEq(raffle.getPlayersCount(), 0);
    }

    function test_ResetRaffle_ResetsHasEnteredMapping() public {
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();

        assertTrue(raffle.hasPlayerEntered(PLAYER));

        vm.prank(owner);
        raffle.resetRaffleGame();

        assertFalse(raffle.hasPlayerEntered(PLAYER));
    }

    function test_ResetRaffle_EmitsEvent() public {
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.prank(PLAYER_2);
        raffle.enterRaffleGame{value: entranceFee}();

        vm.prank(owner);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleReset(2);
        raffle.resetRaffleGame();
    }

    function test_ResetRaffle_AllowsPlayersToReenterAfterReset() public {
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();

        vm.prank(owner);
        raffle.resetRaffleGame();

        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();

        assertEq(raffle.getPlayersCount(), 1);
        assertTrue(raffle.hasPlayerEntered(PLAYER));
    }

    /*//////////////////////////////////////////////////////////////
                        START RAFFLE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_StartRaffle_OnlyOwnerCanStart() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotOwner.selector);
        raffle.startRaffle();
    }

    function test_StartRaffle_RevertsIfAlreadyOpen() public {
        vm.prank(owner);
        vm.expectRevert(Raffle.Raffle__GameAlreadyStarted.selector);
        raffle.startRaffle();
    }

    /*//////////////////////////////////////////////////////////////
                          RECEIVE TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Receive_RevertsDirectETHTransfer() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__DirectETHNotAllowed.selector);
        (bool success,) = address(raffle).call{value: 1 ether}("");
        assertFalse(success);
    }

    /*//////////////////////////////////////////////////////////////
                         GETTER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_GetEntranceFee_ReturnsCorrectValue() public view {
        assertEq(raffle.getEntranceFee(), entranceFee);
    }

    function test_GetRaffleState_ReturnsCorrectState() public view {
        assertEq(uint256(raffle.getRaffleState()), 0); // OPEN
    }

    function test_GetOwner_ReturnsCorrectOwner() public view {
        assertEq(raffle.getOwner(), owner);
    }

    function test_GetTimeInterval_ReturnsCorrectInterval() public view {
        assertEq(raffle.getTimeInterval(), interval);
    }

    function test_GetPlayersCount_ReturnsCorrectCount() public {
        assertEq(raffle.getPlayersCount(), 0);

        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();

        assertEq(raffle.getPlayersCount(), 1);
    }

    function test_GetPlayer_ReturnsCorrectPlayer() public {
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();

        assertEq(raffle.getPlayer(0), PLAYER);
    }

    function test_GetAllPlayers_ReturnsAllPlayers() public {
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();
        vm.prank(PLAYER_2);
        raffle.enterRaffleGame{value: entranceFee}();

        address payable[] memory players = raffle.getAllPlayers();

        assertEq(players.length, 2);
        assertEq(players[0], PLAYER);
        assertEq(players[1], PLAYER_2);
    }

    function test_GetMinimumPlayers_ReturnsCorrectValue() public view {
        assertEq(raffle.getMinimumPlayers(), 3);
    }

    function test_GetPrizePool_ReturnsCorrectBalance() public {
        assertEq(raffle.getPrizePool(), 0);

        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();

        assertEq(raffle.getPrizePool(), entranceFee);
    }

    function test_HasPlayerEntered_ReturnsTrueForEnteredPlayer() public {
        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();

        assertTrue(raffle.hasPlayerEntered(PLAYER));
    }

    function test_HasPlayerEntered_ReturnsFalseForNonEnteredPlayer() public view {
        assertFalse(raffle.hasPlayerEntered(PLAYER));
    }

    /*//////////////////////////////////////////////////////////////
                          FUZZ TESTS
    //////////////////////////////////////////////////////////////*/

    function testFuzz_EnterRaffleGame_AcceptsAnyAmountAboveEntranceFee(uint256 amount) public {
        vm.assume(amount >= entranceFee && amount <= STARTING_PLAYER_BALANCE);

        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: amount}();

        assertEq(raffle.getPlayersCount(), 1);
        assertEq(address(raffle).balance, amount);
    }

    function testFuzz_EnterRaffleGame_RevertsForAmountsBelowEntranceFee(uint256 amount) public {
        vm.assume(amount < entranceFee);

        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughETHsent.selector);
        raffle.enterRaffleGame{value: amount}();
    }
}
