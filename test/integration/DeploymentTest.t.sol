// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {CreateSubscription} from "../../script/interactions/CreateSubscription.s.sol";
import {FundSubscription} from "../../script/interactions/FundSubscription.s.sol";
import {AddConsumer} from "../../script/interactions/AddConsumer.s.sol";
import {VRFCoordinatorV2_5Mock} from "../../test/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";

/**
 * @title DeploymentTest
 * @notice Integration tests for deployment scripts and interactions
 * @dev Tests the complete deployment flow and all interaction scripts
 */
contract DeploymentTest is Test {
    DeployRaffle public deployer;
    Raffle public raffle;
    HelperConfig public helperConfig;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;

    function setUp() external {
        deployer = new DeployRaffle();
    }

    /*//////////////////////////////////////////////////////////////
                       FULL DEPLOYMENT TESTS
    //////////////////////////////////////////////////////////////*/

    function test_Deployment_DeploysRaffleSuccessfully() public {
        (raffle, helperConfig) = deployer.run();

        assertTrue(address(raffle) != address(0));
        assertTrue(address(helperConfig) != address(0));
    }

    function test_Deployment_RaffleHasCorrectConfiguration() public {
        (raffle, helperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        assertEq(raffle.getEntranceFee(), config.entranceFee);
        assertEq(raffle.getTimeInterval(), config.interval);
        assertEq(raffle.getOwner(), config.account);
    }

    function test_Deployment_RaffleStartsInOpenState() public {
        (raffle, helperConfig) = deployer.run();

        assertEq(uint256(raffle.getRaffleState()), 0); // OPEN
    }

    function test_Deployment_RaffleStartsWithZeroPlayers() public {
        (raffle, helperConfig) = deployer.run();

        assertEq(raffle.getPlayersCount(), 0);
    }

    function test_Deployment_SubscriptionIsCreatedAndFunded() public {
        (raffle, helperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(config.vrfCoordinator);

        // Check subscription exists
        (uint96 balance,, address owner, address[] memory consumers) =
            coordinator.getSubscription(config.subscriptionId);

        assertTrue(balance > 0, "Subscription should be funded");
        assertEq(owner, config.account);
        assertTrue(consumers.length > 0, "Should have consumers");
    }

    function test_Deployment_RaffleIsAddedAsConsumer() public {
        (raffle, helperConfig) = deployer.run();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(config.vrfCoordinator);

        (,, address owner, address[] memory consumers) = coordinator.getSubscription(config.subscriptionId);

        bool isConsumer = false;
        for (uint256 i = 0; i < consumers.length; i++) {
            if (consumers[i] == address(raffle)) {
                isConsumer = true;
                break;
            }
        }

        assertTrue(isConsumer, "Raffle should be added as consumer");
    }

    /*//////////////////////////////////////////////////////////////
                    CREATE SUBSCRIPTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_CreateSubscription_CreatesNewSubscription() public {
        CreateSubscription createSub = new CreateSubscription();
        (uint256 subId, address vrfCoordinator, address account) = createSub.run();

        assertTrue(subId > 0);
        assertTrue(vrfCoordinator != address(0));
        assertTrue(account != address(0));
    }

    function test_CreateSubscription_SubscriptionHasCorrectOwner() public {
        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helper.getConfig();

        CreateSubscription createSub = new CreateSubscription();
        (uint256 subId, address vrfCoord,) = createSub.createSubscription(config.vrfCoordinator, config.account);

        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(vrfCoord);
        (,, address owner,) = coordinator.getSubscription(subId);

        assertEq(owner, config.account);
    }

    /*//////////////////////////////////////////////////////////////
                     FUND SUBSCRIPTION TESTS
    //////////////////////////////////////////////////////////////*/

    function test_FundSubscription_FundsSubscriptionSuccessfully() public {
        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helper.getConfig();

        CreateSubscription createSub = new CreateSubscription();
        (uint256 subId,,) = createSub.createSubscription(config.vrfCoordinator, config.account);

        FundSubscription fundSub = new FundSubscription();
        fundSub.fundSubscription(config.vrfCoordinator, subId, config.link, config.account);

        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(config.vrfCoordinator);
        (uint96 balance,,,) = coordinator.getSubscription(subId);

        assertEq(balance, fundSub.FUND_AMOUNT());
    }

    /*//////////////////////////////////////////////////////////////
                      ADD CONSUMER TESTS
    //////////////////////////////////////////////////////////////*/

    function test_AddConsumer_AddsConsumerSuccessfully() public {
        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helper.getConfig();

        CreateSubscription createSub = new CreateSubscription();
        (uint256 subId,,) = createSub.createSubscription(config.vrfCoordinator, config.account);

        address mockConsumer = makeAddr("mockConsumer");

        AddConsumer addCon = new AddConsumer();
        addCon.addConsumer(mockConsumer, config.vrfCoordinator, subId, config.account);

        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(config.vrfCoordinator);
        (,,, address[] memory consumers) = coordinator.getSubscription(subId);

        bool found = false;
        for (uint256 i = 0; i < consumers.length; i++) {
            if (consumers[i] == mockConsumer) {
                found = true;
                break;
            }
        }

        assertTrue(found, "Consumer should be added");
    }

    /*//////////////////////////////////////////////////////////////
                     HELPER CONFIG TESTS
    //////////////////////////////////////////////////////////////*/

    function test_HelperConfig_ReturnsCorrectConfigForLocalChain() public {
        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helper.getConfig();

        // On Anvil (chainId 31337)
        assertTrue(config.vrfCoordinator != address(0));
        assertTrue(config.link != address(0));
        assertTrue(config.entranceFee > 0);
        assertTrue(config.interval > 0);
        assertTrue(config.callbackGasLimit > 0);
    }

    function test_HelperConfig_DeploysMocksForLocalChain() public {
        HelperConfig helper = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helper.getConfig();

        // Verify VRF Coordinator is a contract
        uint256 coordinatorSize;
        address vrfCoord = config.vrfCoordinator;
        assembly {
            coordinatorSize := extcodesize(vrfCoord)
        }
        assertTrue(coordinatorSize > 0, "VRF Coordinator should be deployed");

        // Verify LINK token is a contract
        uint256 linkSize;
        address linkToken = config.link;
        assembly {
            linkSize := extcodesize(linkToken)
        }
        assertTrue(linkSize > 0, "LINK token should be deployed");
    }

    /*//////////////////////////////////////////////////////////////
                     MOCK CONTRACTS TESTS
    //////////////////////////////////////////////////////////////*/

    function test_VRFMock_CanCreateSubscription() public {
        VRFCoordinatorV2_5Mock coordinator = new VRFCoordinatorV2_5Mock(0.25 ether, 1e9);

        uint256 subId = coordinator.createSubscription();

        assertTrue(subId > 0);
    }

    function test_VRFMock_CanFundSubscription() public {
        VRFCoordinatorV2_5Mock coordinator = new VRFCoordinatorV2_5Mock(0.25 ether, 1e9);

        uint256 subId = coordinator.createSubscription();
        coordinator.fundSubscription(subId, 3 ether);

        (uint96 balance,,,) = coordinator.getSubscription(subId);

        assertEq(balance, 3 ether);
    }

    function test_VRFMock_CanAddConsumer() public {
        VRFCoordinatorV2_5Mock coordinator = new VRFCoordinatorV2_5Mock(0.25 ether, 1e9);

        uint256 subId = coordinator.createSubscription();
        address consumer = makeAddr("consumer");
        coordinator.addConsumer(subId, consumer);

        (,,, address[] memory consumers) = coordinator.getSubscription(subId);

        assertEq(consumers.length, 1);
        assertEq(consumers[0], consumer);
    }

    function test_VRFMock_RevertsOnInvalidSubscription() public {
        VRFCoordinatorV2_5Mock coordinator = new VRFCoordinatorV2_5Mock(0.25 ether, 1e9);

        vm.expectRevert(VRFCoordinatorV2_5Mock.VRFCoordinatorV2_5Mock__SubscriptionNotFound.selector);
        coordinator.fundSubscription(999, 1 ether);
    }

    function test_LinkMock_CanMintTokens() public {
        LinkToken link = new LinkToken();

        link.mint(PLAYER, 100 ether);

        assertEq(link.balanceOf(PLAYER), 100 ether);
    }

    function test_LinkMock_CanTransferAndCall() public {
        LinkToken link = new LinkToken();
        address recipient = makeAddr("recipient");

        link.mint(address(this), 100 ether);

        bool success = link.transferAndCall(recipient, 50 ether, "");

        assertTrue(success);
        assertEq(link.balanceOf(recipient), 50 ether);
    }

    /*//////////////////////////////////////////////////////////////
                   END-TO-END INTEGRATION TEST
    //////////////////////////////////////////////////////////////*/

    function test_EndToEnd_CompleteRaffleFlow() public {
        // 1. Deploy everything
        (raffle, helperConfig) = deployer.run();

        // 2. Fund players
        vm.deal(PLAYER, STARTING_BALANCE);
        address player2 = makeAddr("player2");
        vm.deal(player2, STARTING_BALANCE);
        address player3 = makeAddr("player3");
        vm.deal(player3, STARTING_BALANCE);

        // 3. Players enter raffle
        uint256 entranceFee = raffle.getEntranceFee();

        vm.prank(PLAYER);
        raffle.enterRaffleGame{value: entranceFee}();

        vm.prank(player2);
        raffle.enterRaffleGame{value: entranceFee}();

        vm.prank(player3);
        raffle.enterRaffleGame{value: entranceFee}();

        // 4. Fast forward time
        vm.warp(block.timestamp + raffle.getTimeInterval() + 1);
        vm.roll(block.number + 1);

        // 5. Check upkeep
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertTrue(upkeepNeeded);

        // 6. Perform upkeep
        vm.recordLogs();
        raffle.performUpkeep("");

        // 7. Get request ID from logs
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // 8. Fulfill random words
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

        // 9. Verify winner was selected
        address winner = raffle.getRecentWinner();
        assertTrue(winner != address(0));

        // 10. Verify raffle reset to OPEN
        assertEq(uint256(raffle.getRaffleState()), 0); // OPEN

        // 11. Verify players array was cleared
        assertEq(raffle.getPlayersCount(), 0);

        // 12. Verify winner received prize
        assertTrue(winner.balance > STARTING_BALANCE);
    }

    function test_EndToEnd_MultipleRaffleRounds() public {
        (raffle, helperConfig) = deployer.run();

        for (uint256 round = 0; round < 3; round++) {
            // Create new players for each round
            address p1 = address(uint160(round * 3 + 1));
            address p2 = address(uint160(round * 3 + 2));
            address p3 = address(uint160(round * 3 + 3));

            vm.deal(p1, STARTING_BALANCE);
            vm.deal(p2, STARTING_BALANCE);
            vm.deal(p3, STARTING_BALANCE);

            uint256 entranceFee = raffle.getEntranceFee();

            vm.prank(p1);
            raffle.enterRaffleGame{value: entranceFee}();
            vm.prank(p2);
            raffle.enterRaffleGame{value: entranceFee}();
            vm.prank(p3);
            raffle.enterRaffleGame{value: entranceFee}();

            vm.warp(block.timestamp + raffle.getTimeInterval() + 1);
            vm.roll(block.number + 1);

            vm.recordLogs();
            raffle.performUpkeep("");

            Vm.Log[] memory entries = vm.getRecordedLogs();
            bytes32 requestId = entries[1].topics[1];

            HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
            VRFCoordinatorV2_5Mock(config.vrfCoordinator).fulfillRandomWords(uint256(requestId), address(raffle));

            address winner = raffle.getRecentWinner();
            assertTrue(winner != address(0), "Winner should be selected in each round");
            assertEq(uint256(raffle.getRaffleState()), 0, "Raffle should return to OPEN");
            assertEq(raffle.getPlayersCount(), 0, "Players should be cleared");
        }
    }
}
