// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../../src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "../../test/mocks/VRFCoordinatorV2_5Mock.sol";
import {HelperConfig} from "../HelperConfig.s.sol";

/**
 * @title PerformUpkeep
 * @notice Manually triggers raffle upkeep and fulfills VRF request (for testing)
 * @dev Useful for local testing to simulate the full raffle flow
 */
contract PerformUpkeep is Script {
    /**
     * @notice Performs upkeep on a Raffle contract and fulfills the VRF request
     * @param raffleAddress Address of the deployed Raffle contract
     */
    function performUpkeep(address raffleAddress) public {
        Raffle raffle = Raffle(payable(raffleAddress));

        console.log("Checking if upkeep is needed...");
        (bool upkeepNeeded,) = raffle.checkUpkeep("");

        if (!upkeepNeeded) {
            console.log("Upkeep not needed. Requirements:");
            console.log("  - Raffle must be OPEN");
            console.log("  - Enough time must have passed");
            console.log("  - At least 3 players entered");
            console.log("  - Contract has balance");
            return;
        }

        console.log("Upkeep needed! Performing upkeep...");

        vm.startBroadcast();

        // Perform upkeep (triggers VRF request)
        raffle.performUpkeep("");

        vm.stopBroadcast();

        console.log("Upkeep performed! VRF request sent.");

        // If on local chain, we can also fulfill the request
        if (block.chainid == 31337) {
            console.log("Local chain detected. Fulfilling VRF request...");
            fulfillVRFRequest(raffleAddress);
        } else {
            console.log("On live network. Wait for Chainlink VRF to fulfill the request.");
        }
    }

    /**
     * @notice Fulfills a VRF request on local chain (mock only)
     * @param raffleAddress Address of the Raffle contract
     */
    function fulfillVRFRequest(address raffleAddress) public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;

        VRFCoordinatorV2_5Mock coordinator = VRFCoordinatorV2_5Mock(vrfCoordinator);

        vm.startBroadcast();

        // Get the latest request ID (assuming it's the most recent one)
        uint256 requestId = coordinator.getCurrentRequestId();

        console.log("Fulfilling request ID:", requestId);

        // Fulfill the random words request
        coordinator.fulfillRandomWords(requestId, raffleAddress);

        vm.stopBroadcast();

        console.log("VRF request fulfilled! Winner should be selected.");

        // Log winner
        Raffle raffle = Raffle(payable(raffleAddress));
        address winner = raffle.getRecentWinner();
        console.log("Winner:", winner);
    }

    function run() external {
        // This needs to be called with the raffle address
        // Example: forge script script/interactions/PerformUpkeep.s.sol --sig "run(address)" <raffle-address> --rpc-url anvil --broadcast
        revert("PerformUpkeep: Call performUpkeep(address) with raffle address");
    }
}
