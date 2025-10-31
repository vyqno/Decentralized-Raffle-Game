// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription} from "./interactions/CreateSubscription.s.sol";
import {FundSubscription} from "./interactions/FundSubscription.s.sol";
import {AddConsumer} from "./interactions/AddConsumer.s.sol";

/**
 * @title DeployRaffle
 * @author vyqno (Hitesh)
 * @notice Main deployment script for the Raffle contract
 * @dev Handles complete deployment flow including:
 *      1. Network configuration (via HelperConfig)
 *      2. Mock deployment (if local chain)
 *      3. Raffle contract deployment
 *      4. VRF subscription creation (if needed)
 *      5. Adding Raffle as consumer
 *      6. Funding subscription with LINK
 *
 * Usage:
 *   Local: forge script script/DeployRaffle.s.sol --rpc-url $RPC_URL --broadcast
 *   Testnet: forge script script/DeployRaffle.s.sol --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
 */
contract DeployRaffle is Script {
    /*//////////////////////////////////////////////////////////////
                          DEPLOYMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Main deployment function - orchestrates entire deployment
     * @return raffle Deployed Raffle contract
     * @return helperConfig HelperConfig contract with network settings
     */
    function run() external returns (Raffle raffle, HelperConfig helperConfig) {
        // Get network configuration
        helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        // Handle subscription creation if needed
        if (config.subscriptionId == 0) {
            console.log("No subscription ID found. Creating new subscription...");

            CreateSubscription createSubscription = new CreateSubscription();
            (config.subscriptionId,,) = createSubscription.createSubscription(
                config.vrfCoordinator,
                config.account
            );

            console.log("Subscription created! ID:", config.subscriptionId);

            // Fund the subscription
            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fundSubscription(
                config.vrfCoordinator,
                config.subscriptionId,
                config.link,
                config.account
            );
        }

        // Deploy Raffle contract
        raffle = deployRaffle(config);

        // Add Raffle as consumer to the subscription
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            address(raffle),
            config.vrfCoordinator,
            config.subscriptionId,
            config.account
        );

        return (raffle, helperConfig);
    }

    /**
     * @notice Deploys the Raffle contract with given configuration
     * @param config Network configuration from HelperConfig
     * @return raffle Deployed Raffle contract
     */
    function deployRaffle(HelperConfig.NetworkConfig memory config) public returns (Raffle raffle) {
        console.log("==============================================");
        console.log("Deploying Raffle on chain ID:", block.chainid);
        console.log("==============================================");
        console.log("Configuration:");
        console.log("  Entrance Fee:", config.entranceFee);
        console.log("  Interval:", config.interval);
        console.log("  VRF Coordinator:", config.vrfCoordinator);
        console.log("  Subscription ID:", config.subscriptionId);
        console.log("  Callback Gas Limit:", config.callbackGasLimit);
        console.log("==============================================");

        vm.startBroadcast(config.account);

        raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.account,
            config.vrfCoordinator,
            config.gasKeyHash,
            config.subscriptionId,
            config.callbackGasLimit
        );

        vm.stopBroadcast();

        console.log("Raffle deployed at:", address(raffle));
        console.log("==============================================");

        return raffle;
    }
}
