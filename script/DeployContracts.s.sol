// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Script.sol";
import "forge-std/console2.sol";

import {Vault} from "../src/Vault.sol";
import {Marketplace} from "../src/Marketplace.sol";

/// @notice Deploys Vault + Marketplace.
/// @dev    Broadcast with:
///         forge script script/DeployContracts.s.sol:DeployContracts \
///           --rpc-url <RPC_URL> --broadcast --private-key $DEPLOYER_PRIVATE_KEY
///
///         Optional env vars:
///           VAULT_OWNER
///           MARKETPLACE_OWNER
///           MARKETPLACE_INITIAL_FEE_BPS
contract DeployContracts is Script {
    function run() external {
        address deployer = vm.addr(vm.envUint("DEPLOYER_PRIVATE_KEY"));
        console2.log("Deployer:", deployer);

        address vaultOwner = vm.envOr("VAULT_OWNER", deployer);
        address marketplaceOwner = vm.envOr("MARKETPLACE_OWNER", deployer);
        uint256 feeBps = vm.envOr("MARKETPLACE_INITIAL_FEE_BPS", uint256(250)); // 2.5%

        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy Vault
        Vault vault = new Vault(vaultOwner);
        console2.log("Vault:", address(vault));

        // Deploy Marketplace
        Marketplace marketplace = new Marketplace(marketplaceOwner, feeBps);
        console2.log("Marketplace:", address(marketplace));

        vm.stopBroadcast();

        // Final sanity logs
        console2.log("vault.owner():", vault.owner());
        console2.log("marketplace.owner():", marketplace.owner());
        console2.log("marketplace.platformFeeBps():", marketplace.platformFeeBps());
    }
}

