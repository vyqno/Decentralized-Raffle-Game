// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title VRFCoordinatorV2_5Mock
 * @notice Mock VRF Coordinator for local testing
 * @dev Simulates Chainlink VRF v2.5 behavior for Anvil/local chains
 */
contract VRFCoordinatorV2_5Mock {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error VRFCoordinatorV2_5Mock__SubscriptionNotFound();
    error VRFCoordinatorV2_5Mock__InvalidConsumer();
    error VRFCoordinatorV2_5Mock__InsufficientBalance();

    /*//////////////////////////////////////////////////////////////
                                 EVENTS
    //////////////////////////////////////////////////////////////*/

    event SubscriptionCreated(uint256 indexed subId, address owner);
    event SubscriptionFunded(uint256 indexed subId, uint256 oldBalance, uint256 newBalance);
    event SubscriptionConsumerAdded(uint256 indexed subId, address consumer);
    event RandomWordsRequested(
        bytes32 indexed keyHash,
        uint256 requestId,
        uint256 preSeed,
        uint256 indexed subId,
        uint16 minimumRequestConfirmations,
        uint32 callbackGasLimit,
        uint32 numWords,
        bytes extraArgs,
        address indexed sender
    );
    event RandomWordsFulfilled(uint256 indexed requestId, uint256 outputSeed, uint256 payment, bool success);

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    struct Subscription {
        uint96 balance;
        address owner;
        address[] consumers;
    }

    struct Request {
        uint256 subId;
        uint32 callbackGasLimit;
        uint32 numWords;
        address requester;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 private s_currentSubId;
    uint256 private s_currentRequestId;
    uint96 public immutable BASE_FEE;
    uint96 public immutable GAS_PRICE;

    mapping(uint256 => Subscription) private s_subscriptions;
    mapping(uint256 => Request) private s_requests;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(uint96 _baseFee, uint96 _gasPriceLink) {
        BASE_FEE = _baseFee;
        GAS_PRICE = _gasPriceLink;
    }

    /*//////////////////////////////////////////////////////////////
                          SUBSCRIPTION FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Creates a new VRF subscription
     * @return subId The new subscription ID
     */
    function createSubscription() external returns (uint256 subId) {
        s_currentSubId++;
        subId = s_currentSubId;
        s_subscriptions[subId].owner = msg.sender;
        s_subscriptions[subId].balance = 0;

        emit SubscriptionCreated(subId, msg.sender);
        return subId;
    }

    /**
     * @notice Funds a subscription with LINK (mock - just increases balance)
     * @param subId Subscription ID to fund
     * @param amount Amount to fund in LINK
     */
    function fundSubscription(uint256 subId, uint96 amount) external {
        if (s_subscriptions[subId].owner == address(0)) {
            revert VRFCoordinatorV2_5Mock__SubscriptionNotFound();
        }

        uint96 oldBalance = s_subscriptions[subId].balance;
        s_subscriptions[subId].balance += amount;

        emit SubscriptionFunded(subId, oldBalance, oldBalance + amount);
    }

    /**
     * @notice Adds a consumer to a subscription
     * @param subId Subscription ID
     * @param consumer Consumer address to add
     */
    function addConsumer(uint256 subId, address consumer) external {
        if (s_subscriptions[subId].owner == address(0)) {
            revert VRFCoordinatorV2_5Mock__SubscriptionNotFound();
        }

        s_subscriptions[subId].consumers.push(consumer);

        emit SubscriptionConsumerAdded(subId, consumer);
    }

    /**
     * @notice Removes a consumer from a subscription
     * @param subId Subscription ID
     * @param consumer Consumer address to remove
     */
    function removeConsumer(uint256 subId, address consumer) external {
        if (s_subscriptions[subId].owner == address(0)) {
            revert VRFCoordinatorV2_5Mock__SubscriptionNotFound();
        }

        address[] storage consumers = s_subscriptions[subId].consumers;
        for (uint256 i = 0; i < consumers.length; i++) {
            if (consumers[i] == consumer) {
                consumers[i] = consumers[consumers.length - 1];
                consumers.pop();
                break;
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                          VRF REQUEST FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Requests random words
     * @param req The request parameters
     * @return requestId The request ID
     */
    function requestRandomWords(VRFV2PlusClient.RandomWordsRequest calldata req)
        external
        returns (uint256 requestId)
    {
        if (s_subscriptions[req.subId].owner == address(0)) {
            revert VRFCoordinatorV2_5Mock__SubscriptionNotFound();
        }

        // Check if requester is a valid consumer
        bool isValidConsumer = false;
        address[] memory consumers = s_subscriptions[req.subId].consumers;
        for (uint256 i = 0; i < consumers.length; i++) {
            if (consumers[i] == msg.sender) {
                isValidConsumer = true;
                break;
            }
        }
        if (!isValidConsumer) {
            revert VRFCoordinatorV2_5Mock__InvalidConsumer();
        }

        s_currentRequestId++;
        requestId = s_currentRequestId;

        s_requests[requestId] = Request({
            subId: req.subId,
            callbackGasLimit: req.callbackGasLimit,
            numWords: req.numWords,
            requester: msg.sender
        });

        emit RandomWordsRequested(
            req.keyHash,
            requestId,
            0, // preSeed
            req.subId,
            req.requestConfirmations,
            req.callbackGasLimit,
            req.numWords,
            req.extraArgs,
            msg.sender
        );

        return requestId;
    }

    /**
     * @notice Fulfills a random words request (for testing)
     * @param requestId The request ID to fulfill
     * @param consumer The consumer contract address
     */
    function fulfillRandomWords(uint256 requestId, address consumer) external {
        Request memory request = s_requests[requestId];

        // Generate pseudo-random words
        uint256[] memory words = new uint256[](request.numWords);
        for (uint256 i = 0; i < request.numWords; i++) {
            words[i] = uint256(keccak256(abi.encode(requestId, i, block.timestamp, block.prevrandao)));
        }

        // Calculate payment
        uint96 payment = BASE_FEE + GAS_PRICE * request.callbackGasLimit;

        if (s_subscriptions[request.subId].balance < payment) {
            revert VRFCoordinatorV2_5Mock__InsufficientBalance();
        }

        s_subscriptions[request.subId].balance -= payment;

        // Call the consumer
        (bool success,) =
            consumer.call(abi.encodeWithSignature("rawFulfillRandomWords(uint256,uint256[])", requestId, words));

        emit RandomWordsFulfilled(requestId, words[0], payment, success);
    }

    /*//////////////////////////////////////////////////////////////
                           GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Gets subscription details
     * @param subId Subscription ID
     * @return balance Subscription balance
     * @return reqCount Request count (always 0 in mock)
     * @return owner Subscription owner
     * @return consumers List of consumers
     */
    function getSubscription(uint256 subId)
        external
        view
        returns (uint96 balance, uint64 reqCount, address owner, address[] memory consumers)
    {
        if (s_subscriptions[subId].owner == address(0)) {
            revert VRFCoordinatorV2_5Mock__SubscriptionNotFound();
        }

        return (s_subscriptions[subId].balance, 0, s_subscriptions[subId].owner, s_subscriptions[subId].consumers);
    }

    /**
     * @notice Gets current subscription ID counter
     */
    function getCurrentSubId() external view returns (uint256) {
        return s_currentSubId;
    }

    /**
     * @notice Gets current request ID counter
     */
    function getCurrentRequestId() external view returns (uint256) {
        return s_currentRequestId;
    }
}
