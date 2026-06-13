# Contracts (NFT_FRACTION)

This repo contains a small system for **fractionalizing NFTs** into ERC-20 tokens and then **selling those fractions** via a simple marketplace.

## Overview

### Contracts
- **`Vault`**: Accepts an ERC-721 NFT deposit, deploys a fresh **`FractionToken`** (ERC-20) per deposit, and mints the requested fractional supply to the depositor.
- **`FractionToken`**: ERC-20 token representing fractional ownership stakes in a vaulted NFT. Only the `Vault` may mint/burn.
- **`Marketplace`**: Lists and sells escrowed batches of `FractionToken` for **native ETH**, using a configurable platform fee (bps).

### Flow
1. A user deposits an NFT into **`Vault`**.
2. `Vault` deploys a **new `FractionToken`** and mints fractional tokens to the depositor.
3. The seller approves and lists `FractionToken` on **`Marketplace`**.
4. A buyer pays ETH to purchase; the marketplace transfers tokens and accrues platform fees.

---

## Vault (`src/Vault.sol`)

### Purpose
- Locks an ERC-721 NFT in the contract.
- Creates a unique fractional ERC-20 token contract per deposit.
- Keeps an internal registry of vault entries.

### Key concepts
- **`vaultId`**: Monotonically increasing identifier for each deposit.
- Vault entries are represented by:

```solidity
struct LockedNFT {
    address nftContract;
    uint256 tokenId;
    address fractionToken;
    uint256 fractionSupply;
    address depositor;
    bool active;
}
```

### Access control
- `Vault` is `Ownable` (owner set in constructor).
- `deposit` is permissionless.

### `deposit(...)`

```solidity
function deposit(
    address nftContract,
    uint256 tokenId,
    uint256 fractionSupply,
    string calldata name_,
    string calldata symbol_
) external nonReentrant returns (uint256 vaultId)
```

**What it does**
- Transfers the ERC-721 from the caller to `Vault` via `safeTransferFrom`.
- Deploys a new `FractionToken` owned by the `Vault` contract.
- Registers the vault entry.
- Mints `fractionSupply * 1e18` tokens to the depositor.

**Decimals / units**
- The FractionToken is a standard ERC-20 with 18 decimals.
- `fractionSupply` is treated as **whole-token units** and minted as `fractionSupply * 10**18`.

**Reverts**
- `ZeroAddress()` if `nftContract == address(0)`.
- `ZeroSupply()` if `fractionSupply == 0`.
- `AlreadyVaulted(tokenId)` if the same `(nftContract, tokenId)` has already been vaulted.

### View helpers

- `getLockedNFT(vaultId)`
  - Returns full metadata.
  - Reverts with `VaultNotFound(vaultId)` if `vaultId >= _nextVaultId`.

- `isVaulted(nftContract, tokenId)`
  - Returns whether a given NFT is currently vaulted.
  - Implementation stores `vaultId + 1` in `_vaultIndex` so that `0` means “not vaulted”.

- `totalVaults()`
  - Returns number of vault entries created so far.

### ERC-721 reception
- `Vault` inherits `ERC721Holder`, so it can receive safe transfers.

---

## FractionToken (`src/FractionToken.sol`)

### Purpose
An ERC-20 token representing fractional ownership for a single vaulted NFT.

### Key characteristics
- Inherits `ERC20` and `Ownable`.
- The `Vault` contract is the token owner.
- Only the owning `Vault` may mint and burn.
- Stores an on-chain label `assetName` for UI use.

### Constructor

```solidity
constructor(
    string memory name_,
    string memory symbol_,
    string memory assetName_,
    address vault_
) ERC20(name_, symbol_) Ownable(vault_)
```

**Reverts**
- `OwnableInvalidOwner(address(0))` (OpenZeppelin) if `vault_ == address(0)`.

### Vault-only token management

- `mint(address to, uint256 amount)`
  - `onlyOwner` (Vault only)
  - Reverts with `ZeroAddress()` if `to == address(0)`
  - Reverts with `ZeroAmount()` if `amount == 0`

- `burn(address from, uint256 amount)`
  - `onlyOwner` (Vault only)
  - Reverts with `ZeroAddress()` if `from == address(0)`
  - Reverts with `ZeroAmount()` if `amount == 0`

---

## Marketplace (`src/Marketplace.sol`)

### Purpose
List and sell `FractionToken` batches for **native ETH**, charging a platform fee in **basis points**.

### Listing model

```solidity
struct Listing {
    address seller;
    address tokenAddress;
    uint256 amount;         // escrowed token amount (wei units, 18 decimals)
    uint256 pricePerToken;  // ETH per 1e18 token units (wei)
    bool active;
}
```

### Fees
- Maximum fee is capped at:

```solidity
uint256 public constant MAX_FEE_BPS = 1_000; // 10 %
```

- Fee formula:

```solidity
fee = (totalPrice * platformFeeBps) / 10_000
```

### Constructor

```solidity
constructor(address owner_, uint256 initialFeeBps) Ownable(owner_)
```

**Reverts**
- `ZeroAddress()` if `owner_ == address(0)`.
- `FeeTooHigh(MAX_FEE_BPS, initialFeeBps)` if `initialFeeBps > MAX_FEE_BPS`.

### Listing: `listFraction(...)`

```solidity
function listFraction(
    address tokenAddress,
    uint256 amount,
    uint256 pricePerToken
) external whenNotPaused returns (uint256 listingId)
```

**What it does**
- Validates inputs.
- Pulls tokens from the seller into escrow using `safeTransferFrom`.
- Stores listing details and marks it active.

**Reverts**
- `ZeroAddress()` if `tokenAddress == address(0)`
- `ZeroAmount()` if `amount == 0`
- `ZeroPrice()` if `pricePerToken == 0`

### Purchasing: `buyFraction(listingId)`

```solidity
function buyFraction(uint256 listingId)
    external payable nonReentrant whenNotPaused
```

**Price math**
- `totalPrice = (listing.amount * listing.pricePerToken) / 1e18`
- `fee = (totalPrice * platformFeeBps) / 10_000`
- `sellerProceeds = totalPrice - fee`

**Behavior**
- Requires `msg.value == totalPrice`.
- Deactivates listing.
- Transfers escrowed tokens to the buyer.
- Sends proceeds to the seller.
- Accumulates fees in `accruedFees`.

**Reverts**
- `ListingNotActive(listingId)` if inactive.
- `IncorrectPayment(required, sent)` if ETH amount is wrong.
- `ETHTransferFailed()` if seller ETH transfer fails.

### Canceling: `cancelListing(listingId)`
- Only the seller can cancel.
- Returns escrowed tokens.
- Does **not** depend on pause state.

**Reverts**
- `ListingNotActive(listingId)` if inactive.
- `NotSeller(listingId)` if `msg.sender != seller`.

### Admin functions

- `updatePlatformFee(newFee)`
  - `onlyOwner`
  - Enforces max fee cap.

- `withdrawFees(to)`
  - `onlyOwner` and `nonReentrant`
  - Transfers all `accruedFees` to `to`.

- `pause()` / `unpause()`
  - Disables `listFraction` and `buyFraction`.

### View helpers
- `getListing(listingId)`
- `totalCost(listingId)` → `(total, fee, sellerProceeds)`
- `totalListings()` → `_nextListingId`

---

## Deployment script (`script/DeployContracts.s.sol`)

Uses Foundry scripting.

Environment variables:
- `DEPLOYER_PRIVATE_KEY`
- `VAULT_OWNER`
- `MARKETPLACE_OWNER`
- `MARKETPLACE_INITIAL_FEE_BPS`

Example:

```bash
forge script script/DeployContracts.s.sol:DeployContracts \
  --rpc-url <your_rpc_url> --broadcast \
  --private-key $DEPLOYER_PRIVATE_KEY
```

---

## Testing

Run:

```bash
forge test
```

Tests included:
- `test/Vault.t.sol`
- `test/FractionToken.t.sol`
- `test/Marketplace.t.sol`

---

## Notes
- Platform fees are in basis points with a 10% ceiling.
- The marketplace sells **fraction tokens** for **native ETH**.
- No EIP-2981 royalty support is implemented.