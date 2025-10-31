// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "../HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "../../test/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../../test/mocks/LinkToken.sol";

/**
 * @title FundSubscription
 * @notice Funds a VRF subscription with LINK tokens
 * @dev Works with both real LINK tokens and mocks
 */
contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 3 ether; // 3 LINK

    /**
     * @notice Funds a subscription using config from HelperConfig
     * @param subId Subscription ID to fund
     */
    function fundSubscriptionUsingConfig(uint256 subId) public {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
        fundSubscription(config.vrfCoordinator, subId, config.link, config.account);
    }

    /**
     * @notice Funds a subscription with LINK
     * @param vrfCoordinator Address of the VRF coordinator
     * @param subId Subscription ID to fund
     * @param linkToken Address of the LINK token
     * @param account Account to broadcast from
     */
    function fundSubscription(address vrfCoordinator, uint256 subId, address linkToken, address account) public {
        console.log("Funding subscription:", subId);
        console.log("Using VRF Coordinator:", vrfCoordinator);
        console.log("On chain ID:", block.chainid);

        vm.startBroadcast(account);

        if (block.chainid == 31337) {
            // Local chain - use mock
            // First mint LINK to the account
            LinkToken(linkToken).mint(account, FUND_AMOUNT);
            // Fund the subscription directly (mock doesn't require transferAndCall)
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subId, FUND_AMOUNT);
        } else {
            // Real network - use transferAndCall
            // Note: This requires the caller to have LINK tokens
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subId));
        }

        vm.stopBroadcast();

        console.log("Subscription funded with", FUND_AMOUNT / 1e18, "LINK");
    }

    function run() external {
        // This would need to be called with parameters
        revert("FundSubscription: Use fundSubscriptionUsingConfig() or fundSubscription() directly");
    }
}
