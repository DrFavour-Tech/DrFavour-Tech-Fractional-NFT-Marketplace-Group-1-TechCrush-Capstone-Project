// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/utils/ERC721Holder.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./FractionToken.sol";

/// @title  Vault
/// @notice Accepts ERC-721 NFTs, deploys a fresh FractionToken per deposit,
///         and mints the requested fractional supply to the depositor.
///         Each vault entry is identified by a monotonically incrementing vaultId.
contract Vault is ERC721Holder, ReentrancyGuard, Ownable {
    // ─────────────────────────────────────────────────────────── errors ──
    error ZeroAddress();
    error ZeroSupply();
    error NotVaulted(uint256 tokenId);
    error AlreadyVaulted(uint256 tokenId);
    error VaultNotFound(uint256 vaultId);
    error NotOwner();
    error InsufficientFractions(); // <--- For redemption checks

    // ─────────────────────────────────────────────────────────── events ──
    event NFTDeposited(
        uint256 indexed vaultId,
        address indexed depositor,
        address indexed nftContract,
        uint256 tokenId,
        address fractionToken,
        uint256 fractionSupply
    );

    event NFTRedeemed(uint256 indexed vaultId, address indexed redeemer); // To Redeem NfT for eligible users

    // ─────────────────────────────────────────── structs / storage ──
    struct LockedNFT {
        address nftContract;
        uint256 tokenId;
        address fractionToken;
        uint256 fractionSupply;
        address depositor;
        bool active;
    }

    uint256 private _nextVaultId;

    /// vaultId → LockedNFT
    mapping(uint256 => LockedNFT) private _vaults;

    /// nftContract → tokenId → vaultId+1  (0 means not vaulted)
    mapping(address => mapping(uint256 => uint256)) private _vaultIndex;

    // ──────────────────────────────────────────────────────── constructor ──
    constructor(address owner_) Ownable(owner_) {
        if (owner_ == address(0)) revert ZeroAddress();
    }

    // ────────────────────────────────────────────────────── core logic ──
    /// @notice Lock an NFT and receive freshly-minted fractional ERC-20 tokens.
    /// @param nftContract    Address of the ERC-721 contract.
    /// @param tokenId        Token ID to deposit.
    /// @param fractionSupply Total fractional tokens to mint (no decimals — treated as whole units × 10^18 by ERC-20).
    /// @param name_          Name for the new FractionToken.
    /// @param symbol_        Symbol for the new FractionToken.
    /// @return vaultId       Identifier for this vault entry.
    function deposit(
        address nftContract,
        uint256 tokenId,
        uint256 fractionSupply,
        string calldata name_,
        string calldata symbol_
    ) external nonReentrant returns (uint256 vaultId) {
        if (nftContract == address(0)) revert ZeroAddress();
        if (fractionSupply == 0) revert ZeroSupply();
        if (_vaultIndex[nftContract][tokenId] != 0)
            revert AlreadyVaulted(tokenId);

        // Pull the NFT from the caller (caller must approve this contract first)
        IERC721(nftContract).safeTransferFrom(msg.sender, address(this), tokenId);

        // Deploy a new FractionToken owned by this Vault
        FractionToken ft = new FractionToken(name_, symbol_, name_, address(this));

        // Register the vault entry
        vaultId = _nextVaultId++;
        _vaults[vaultId] = LockedNFT({
            nftContract: nftContract,
            tokenId: tokenId,
            fractionToken: address(ft),
            fractionSupply: fractionSupply,
            depositor: msg.sender,
            active: true
        });
        _vaultIndex[nftContract][tokenId] = vaultId + 1; // +1 so 0 stays "not vaulted"

        // Mint all fractions directly to the depositor
        ft.mint(msg.sender, fractionSupply * (10 ** 18));

        emit NFTDeposited(
            vaultId,
            msg.sender,
            nftContract,
            tokenId,
            address(ft),
            fractionSupply
        );
    }

    /// @notice Allows a user holding 100% of the fractions to claim the underlying NFT.
    /// @param vaultId The ID of the vault entry containing the target asset.
    function redeemNFT(uint256 vaultId) external nonReentrant {
        if (vaultId >= _nextVaultId) revert VaultNotFound(vaultId);
        
        LockedNFT storage vaultEntry = _vaults[vaultId];
        if (!vaultEntry.active) revert NotVaulted(vaultEntry.tokenId);

        // 1. Calculate required amount (accounting for ERC-20 decimals)
        uint256 requiredSupply = vaultEntry.fractionSupply * (10 ** 18);
        
        // 2. Query user's fraction balance
        FractionToken ft = FractionToken(vaultEntry.fractionToken);
        if (ft.balanceOf(msg.sender) < requiredSupply) revert InsufficientFractions();

        // 3. Update State *before* external calls to completely negate reentrancy attack vectors
        vaultEntry.active = false;
        _vaultIndex[vaultEntry.nftContract][vaultEntry.tokenId] = 0; // Free up the index for future deposits

        // 4. Burn the tokens from the user's wallet
        // CRITICAL ASSUMPTION: The FractionToken must allow the Vault (owner) to execute this burn.
        ft.burn(msg.sender, requiredSupply);

        // 5. Release physical custody of the asset
        IERC721(vaultEntry.nftContract).safeTransferFrom(address(this), msg.sender, vaultEntry.tokenId);

        emit NFTRedeemed(vaultId, msg.sender);
    }

    // ──────────────────────────────────────────────────── view helpers ──
    /// @notice Returns full metadata for a vault entry.
    function getLockedNFT(uint256 vaultId)
        external
        view
        returns (LockedNFT memory)
    {
        if (vaultId >= _nextVaultId) revert VaultNotFound(vaultId);
        return _vaults[vaultId];
    }

    /// @notice Returns true if `tokenId` from `nftContract` is currently vaulted.
    function isVaulted(address nftContract, uint256 tokenId)
        external
        view
        returns (bool)
    {
        uint256 idx = _vaultIndex[nftContract][tokenId];
        if (idx == 0) return false;
        return _vaults[idx - 1].active;
    }

    /// @notice Convenience: total number of vault entries ever created.
    function totalVaults() external view returns (uint256) {
        return _nextVaultId;
    }
}
