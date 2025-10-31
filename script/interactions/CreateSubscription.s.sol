// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "../../test/mocks/VRFCoordinatorV2_5Mock.sol";

/**
 * @title CreateSubscription
 * @notice Creates a Chainlink VRF subscription
 * @dev Works with both real VRF coordinators and mocks
 */
contract CreateSubscription is Script {
    /**
     * @notice Creates a subscription using config from HelperConfig
     * @return subId The created subscription ID
     * @return vrfCoordinator The VRF coordinator address
     * @return account The account that created the subscription
     */
    function createSubscriptionUsingConfig() public returns (uint256 subId, address vrfCoordinator, address account) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        (subId, vrfCoordinator) = createSubscription(config.vrfCoordinator, config.account);
        account = config.account;
        return (subId, vrfCoordinator, account);
    }

    /**
     * @notice Creates a subscription on a specific VRF coordinator
     * @param vrfCoordinator Address of the VRF coordinator
     * @param account Account to broadcast from
     * @return subId The created subscription ID
     * @return vrfCoordinatorAddr The VRF coordinator address
     */
    function createSubscription(address vrfCoordinator, address account)
        public
        returns (uint256 subId, address vrfCoordinatorAddr)
    {
        console.log("Creating subscription on VRF Coordinator:", vrfCoordinator);

        vm.startBroadcast(account);
        subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();

        console.log("Subscription created! ID:", subId);
        return (subId, vrfCoordinator);
    }

    function run() external returns (uint256 subId, address vrfCoordinator, address account) {
        return createSubscriptionUsingConfig();
    }
}
