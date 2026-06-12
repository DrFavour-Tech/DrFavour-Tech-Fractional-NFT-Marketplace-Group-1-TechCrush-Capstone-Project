// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Script.sol";

import "../src/Vault.sol";
import "../src/Marketplace.sol";

/**
 * @notice Deployment script for Vault + Marketplace.
 *
 * Environment variables (recommended):
 * - DEPLOYER_PRIVATE_KEY
 * - VAULT_OWNER
 * - MARKETPLACE_OWNER
 * - MARKETPLACE_INITIAL_FEE_BPS
 *
 * Example:
 * forge script script/DeployContracts.s.sol:DeployContracts \
 *   --rpc-url <your_rpc_url> --broadcast \
 *   --private-key $DEPLOYER_PRIVATE_KEY
 *
 * Note: This repo’s instruction says not to execute scripts here; this file is provided for deployment readiness.
 */
contract DeployContracts is Script {
    function run() external {
        uint256 deployerPk = vm.envUint("DEPLOYER_PRIVATE_KEY");
        address vaultOwner = vm.envAddress("VAULT_OWNER");
        address marketplaceOwner = vm.envAddress("MARKETPLACE_OWNER");
        uint256 initialFeeBps = vm.envUint("MARKETPLACE_INITIAL_FEE_BPS");

        vm.startBroadcast(deployerPk);

        Vault vault = new Vault(vaultOwner);

        Marketplace marketplace = new Marketplace(marketplaceOwner, initialFeeBps);

        vm.stopBroadcast();

        // Silence unused vars warnings if any tooling complains
        (vault, marketplace);
    }
}
