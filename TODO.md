# TODO - Contract tests

- [ ] Create Foundry test suite for Vault, FractionToken, Marketplace.
- [ ] Add minimal mock ERC721 and receiver to test Vault deposit behavior.
- [ ] Add test cases for Vault: constructor, deposit happy path, zero address/supply, already vaulted, isVaulted/getLockedNFT/totalVaults.
- [ ] Add test cases for FractionToken: assetName storage, mint/burn access control (only owner), zero checks.
- [ ] Add test cases for Marketplace: constructor fee cap, listFraction happy path + escrow transfer, buyFraction price/fee math + access + reverts, cancelListing, updatePlatformFee, withdrawFees, pause/unpause.
- [ ] Run `forge test` and iterate until green.

# TODO - Deployment scripts

- [x] Add Foundry deployment script for Vault + Marketplace (`script/DeployContracts.s.sol`).

