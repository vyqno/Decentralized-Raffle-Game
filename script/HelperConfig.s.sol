// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {Script} from "forge-std/Script.sol";

/**
 * @title HelperConfig
 * @author vyqno (Hitesh)
 * @notice Helper configuration contract for deploying Raffle across different networks
 * @dev Provides network-specific Chainlink VRF v2.5 configurations
 *
 * Supported Networks:
 * - Ethereum Sepolia
 * - Base Sepolia
 * - BNB Chain Testnet
 * - Polygon Amoy
 * - Local Anvil (with mocks)
 *
 * Configuration sources:
 * - VRF Addresses: https://docs.chain.link/vrf/v2-5/supported-networks
 * - LINK Tokens: https://docs.chain.link/resources/link-token-contracts
 */
contract HelperConfig is Script {
    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/

    error HelperConfig__InvalidChainId();

    /*//////////////////////////////////////////////////////////////
                                 TYPES
    //////////////////////////////////////////////////////////////*/

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasKeyHash;
        uint256 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        address account;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/

    uint256 constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 constant BASE_SEPOLIA_CHAIN_ID = 84532;
    uint256 constant BNB_TESTNET_CHAIN_ID = 97;
    uint256 constant POLYGON_AMOY_CHAIN_ID = 80002;
    uint256 constant LOCAL_CHAIN_ID = 31337;

    // Default raffle parameters
    uint256 constant DEFAULT_ENTRANCE_FEE = 0.01 ether;
    uint256 constant DEFAULT_INTERVAL = 30 seconds;
    uint32 constant DEFAULT_CALLBACK_GAS_LIMIT = 500000;

    NetworkConfig public activeNetworkConfig;

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor() {
        if (block.chainid == ETH_SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else if (block.chainid == BASE_SEPOLIA_CHAIN_ID) {
            activeNetworkConfig = getBaseSepoliaConfig();
        } else if (block.chainid == BNB_TESTNET_CHAIN_ID) {
            activeNetworkConfig = getBnbTestnetConfig();
        } else if (block.chainid == POLYGON_AMOY_CHAIN_ID) {
            activeNetworkConfig = getPolygonAmoyConfig();
        } else if (block.chainid == LOCAL_CHAIN_ID) {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    /*//////////////////////////////////////////////////////////////
                         NETWORK CONFIGURATIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Ethereum Sepolia testnet configuration
     * @dev Verified addresses from Chainlink documentation (January 2025)
     * @return NetworkConfig struct with Sepolia parameters
     *
     * Sources:
     * - VRF Coordinator: https://docs.chain.link/vrf/v2-5/supported-networks#ethereum-sepolia
     * - LINK Token: https://docs.chain.link/resources/link-token-contracts#ethereum-sepolia
     */
    function getSepoliaEthConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: DEFAULT_ENTRANCE_FEE,
            interval: DEFAULT_INTERVAL,
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B, // VRF Coordinator v2.5
            gasKeyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, // 150 gwei Key Hash
            subscriptionId: 0, // Update with your subscription ID
            callbackGasLimit: DEFAULT_CALLBACK_GAS_LIMIT,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789, // LINK Token
            account: 0x643315C9Be056cDEA171F4e7b2222a4ddaB9F88D // Default Foundry address
        });
    }

    /**
     * @notice Base Sepolia testnet configuration
     * @dev VRF v2.5 is supported on Base Sepolia
     * @return NetworkConfig struct with Base Sepolia parameters
     *
     * NOTE: Update VRF Coordinator and Key Hash from:
     * https://docs.chain.link/vrf/v2-5/supported-networks#base-sepolia
     *
     * Chain ID: 84532
     */
    function getBaseSepoliaConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: DEFAULT_ENTRANCE_FEE,
            interval: DEFAULT_INTERVAL,
            vrfCoordinator: 0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE, // VRF Coordinator v2.5 (verify)
            gasKeyHash: 0xc799bd1e3bd4d1a41cd4968997a4e03dfd2a3c7c04b695881138580163f42887, // 100 gwei Key Hash (verify)
            subscriptionId: 0, // Update with your subscription ID
            callbackGasLimit: DEFAULT_CALLBACK_GAS_LIMIT,
            link: 0xE4aB69C077896252FAFBD49EFD26B5D171A32410, // LINK Token
            account: 0x643315C9Be056cDEA171F4e7b2222a4ddaB9F88D // Default Foundry address
        });
    }

    /**
     * @notice BNB Chain Testnet configuration
     * @dev VRF v2.5 is supported on BNB Chain testnet
     * @return NetworkConfig struct with BNB testnet parameters
     *
     * NOTE: Update VRF Coordinator and Key Hash from:
     * https://docs.chain.link/vrf/v2-5/supported-networks#bnb-chain-testnet
     *
     * Chain ID: 97
     * Faucet: https://faucets.chain.link/bnb-chain-testnet
     */
    function getBnbTestnetConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: DEFAULT_ENTRANCE_FEE,
            interval: DEFAULT_INTERVAL,
            vrfCoordinator: 0xDA3b641D438362C440Ac5458c57e00a712b66700, // VRF Coordinator v2.5 (verify)
            gasKeyHash: 0x8596b430971ac45bdf6088665b9ad8e8630c9d5049ab54b14dff711bee7c0e26, // 100 gwei Key Hash (verify)
            subscriptionId: 0, // Update with your subscription ID
            callbackGasLimit: DEFAULT_CALLBACK_GAS_LIMIT,
            link: 0x84b9B910527Ad5C03A9Ca831909E21e236EA7b06, // LINK Token
            account: 0x643315C9Be056cDEA171F4e7b2222a4ddaB9F88D // Default Foundry address
        });
    }

    /**
     * @notice Polygon Amoy testnet configuration
     * @dev Polygon Mumbai has been deprecated, use Amoy instead
     * @return NetworkConfig struct with Polygon Amoy parameters
     *
     * NOTE: Update VRF Coordinator and Key Hash from:
     * https://docs.chain.link/vrf/v2-5/supported-networks#polygon-amoy-testnet
     *
     * Chain ID: 80002
     * Faucet: https://faucets.chain.link/polygon-amoy
     */
    function getPolygonAmoyConfig() public view returns (NetworkConfig memory) {
        return NetworkConfig({
            entranceFee: DEFAULT_ENTRANCE_FEE,
            interval: DEFAULT_INTERVAL,
            vrfCoordinator: 0x343300b5d84D444B2ADc9116FEF1bED02BE49Cf2, // VRF Coordinator v2.5 (verify)
            gasKeyHash: 0x3f631d5ec60a0ce16203bcd1aff2d89aa1c7f94c620bb525a01dc88d09f069e3, // 100 gwei Key Hash (verify)
            subscriptionId: 0, // Update with your subscription ID
            callbackGasLimit: DEFAULT_CALLBACK_GAS_LIMIT,
            link: 0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904, // LINK Token
            account: 0x643315C9Be056cDEA171F4e7b2222a4ddaB9F88D // Default Foundry address
        });
    }

    /**
     * @notice Local Anvil network configuration with mocks
     * @dev Deploys mock VRF Coordinator for local testing
     * @return NetworkConfig struct with local parameters
     *
     * Chain ID: 31337 (Anvil default)
     */
    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        // Check if already deployed
        if (activeNetworkConfig.vrfCoordinator != address(0)) {
            return activeNetworkConfig;
        }

        // TODO: Deploy mocks here
        // 1. Deploy MockLinkToken
        // 2. Deploy VRFCoordinatorV2_5Mock
        // 3. Create subscription
        // 4. Fund subscription

        // For now, return placeholder config
        return NetworkConfig({
            entranceFee: DEFAULT_ENTRANCE_FEE,
            interval: DEFAULT_INTERVAL,
            vrfCoordinator: address(0), // Deploy mock
            gasKeyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            subscriptionId: 0,
            callbackGasLimit: DEFAULT_CALLBACK_GAS_LIMIT,
            link: address(0), // Deploy mock
            account: 0x643315C9Be056cDEA171F4e7b2222a4ddaB9F88D
        });
    }

    /*//////////////////////////////////////////////////////////////
                           GETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the active network configuration
     * @return NetworkConfig struct for current chain
     */
    function getConfig() public view returns (NetworkConfig memory) {
        return activeNetworkConfig;
    }

    /**
     * @notice Returns configuration for a specific chain ID
     * @param chainId The chain ID to get config for
     * @return NetworkConfig struct for specified chain
     */
    function getConfigByChainId(uint256 chainId) public view returns (NetworkConfig memory) {
        if (chainId == ETH_SEPOLIA_CHAIN_ID) {
            return getSepoliaEthConfig();
        } else if (chainId == BASE_SEPOLIA_CHAIN_ID) {
            return getBaseSepoliaConfig();
        } else if (chainId == BNB_TESTNET_CHAIN_ID) {
            return getBnbTestnetConfig();
        } else if (chainId == POLYGON_AMOY_CHAIN_ID) {
            return getPolygonAmoyConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }
}
