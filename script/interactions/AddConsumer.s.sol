// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "../../test/mocks/VRFCoordinatorV2_5Mock.sol";

/**
 * @title AddConsumer
 * @notice Adds a consumer contract to a VRF subscription
 * @dev Works with both real VRF coordinators and mocks
 */
contract AddConsumer is Script {
    /**
     * @notice Adds a consumer using config from HelperConfig
     * @param consumer Address of the consumer contract to add
     * @param subId Subscription ID to add consumer to
     */
    function addConsumerUsingConfig(address consumer, uint256 subId) public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        addConsumer(consumer, config.vrfCoordinator, subId, config.account);
    }

    /**
     * @notice Adds a consumer to a specific subscription
     * @param consumer Address of the consumer contract
     * @param vrfCoordinator Address of the VRF coordinator
     * @param subId Subscription ID
     * @param account Account to broadcast from
     */
    function addConsumer(address consumer, address vrfCoordinator, uint256 subId, address account) public {
        console.log("Adding consumer:", consumer);
        console.log("To VRF Coordinator:", vrfCoordinator);
        console.log("On subscription:", subId);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subId, consumer);
        vm.stopBroadcast();

        console.log("Consumer added successfully!");
    }

    function run() external {
        // This would need to be called with parameters
        // Example: forge script script/interactions/AddConsumer.s.sol --sig "run(address,uint256)" <consumer> <subId>
        revert("AddConsumer: Use addConsumerUsingConfig() or addConsumer() directly");
    }
}
