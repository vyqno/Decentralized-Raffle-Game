// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {ERC20} from "forge-std/mocks/MockERC20.sol";

/**
 * @title LinkToken
 * @notice Mock LINK token for local testing
 * @dev Simple ERC20 implementation for testing VRF subscriptions
 */
contract LinkToken is ERC20 {
    constructor() {
        initialize("Chainlink Token", "LINK", 18);
    }

    /**
     * @notice Mints LINK tokens to an address
     * @param to Address to receive tokens
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    /**
     * @notice Transfer and call function (ERC677)
     * @param to Address to transfer to
     * @param value Amount to transfer
     * @param data Data to pass to receiving contract
     * @return success True if successful
     */
    function transferAndCall(address to, uint256 value, bytes memory data) public returns (bool success) {
        transfer(to, value);
        // In a real LINK token, this would call onTokenTransfer on the receiver
        // For mock purposes, we just do the transfer
        return true;
    }
}
