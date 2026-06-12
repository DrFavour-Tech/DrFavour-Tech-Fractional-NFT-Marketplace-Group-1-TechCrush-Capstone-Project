// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/// @title  FractionToken
/// @notice ERC-20 token representing fractional ownership stakes in a vaulted NFT.
///         Only the Vault contract (owner) may mint or burn tokens.
contract FractionToken is ERC20, Ownable {
    // ─────────────────────────────────────────────────────────── errors ──
    error ZeroAmount();
    error ZeroAddress();

    // ───────────────────────────────────────────────────────── metadata ──
    /// @notice Human-readable name of the underlying vaulted asset.
    string public assetName;

    // ──────────────────────────────────────────────────────── constructor ──
    /// @param name_       ERC-20 name  (e.g. "Fraction: Bored Ape #1234")
    /// @param symbol_     ERC-20 symbol (e.g. "fBAYC1234")
    /// @param assetName_  Plain-English label stored on-chain for UI use
    /// @param vault_      Address of the Vault that will own this contract
    constructor(
        string memory name_,
        string memory symbol_,
        string memory assetName_,
        address vault_
    ) ERC20(name_, symbol_) Ownable(vault_) {
        if (vault_ == address(0)) revert ZeroAddress();
        assetName = assetName_;
    }

    // ──────────────────────────────────────────────────── vault interface ──
    /// @notice Mint `amount` tokens to `to`. Callable only by the Vault.
    function mint(address to, uint256 amount) external onlyOwner {
        if (to == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        _mint(to, amount);
    }

    /// @notice Burn `amount` tokens from `from`. Callable only by the Vault.
    function burn(address from, uint256 amount) external onlyOwner {
        if (from == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        _burn(from, amount);
    }
}
