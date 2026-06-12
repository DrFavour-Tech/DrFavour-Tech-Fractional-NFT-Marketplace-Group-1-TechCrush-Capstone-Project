// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";

/// @title  Marketplace
/// @notice Lists and sells fractional ERC-20 tokens (from Vault-deployed FractionTokens).
///         Prices are denominated in native ETH. Platform fees use basis points (bps).
///         Fee formula: fee = (price × platformFeeBps) / 10_000
///         No EIP-2981 royalty support — excluded by design.
contract Marketplace is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

    // custom errors
    error ZeroAddress();
    error ZeroAmount();
    error ZeroPrice();
    error ListingNotActive(uint256 listingId);
    error NotSeller(uint256 listingId);
    error IncorrectPayment(uint256 required, uint256 sent);
    error FeeTooHigh(uint256 maxBps, uint256 provided);
    error ETHTransferFailed();

    // ─────────────────────────────────────────────────────────── events ──
    event Listed(
        uint256 indexed listingId,
        address indexed seller,
        address indexed tokenAddress,
        uint256 amount,
        uint256 pricePerToken
    );
    event Purchased(
        uint256 indexed listingId,
        address indexed buyer,
        uint256 totalPrice,
        uint256 platformFee
    );
    event ListingCancelled(uint256 indexed listingId);
    event PlatformFeeUpdated(uint256 oldFee, uint256 newFee);
    event FeesWithdrawn(address indexed to, uint256 amount);

    // listing
    struct Listing {
        address seller;
        address tokenAddress;
        uint256 amount;         // token amount in wei (18 dec)
        uint256 pricePerToken;  // ETH per whole token (18 dec), in wei
        bool active;
    }

    uint256 public constant MAX_FEE_BPS = 1_000; // 10 % ceiling

    uint256 public platformFeeBps;
    uint256 public accruedFees;

    uint256 private _nextListingId;
    mapping(uint256 => Listing) private _listings;

    //Initial owner (receives fees, can admin).
    //Starting platform fee in basis points (e.g. 250 = 2.5 %).
    constructor(address owner_, uint256 initialFeeBps) Ownable(owner_) {
        if (owner_ == address(0)) revert ZeroAddress();
        if (initialFeeBps > MAX_FEE_BPS)
            revert FeeTooHigh(MAX_FEE_BPS, initialFeeBps);
        platformFeeBps = initialFeeBps;
    }

    /// @notice Escrow `amount` of `tokenAddress` for sale at `pricePerToken` ETH.
    /// @param tokenAddress  FractionToken contract address.
    /// @param amount        Token amount to list (in wei, 18 decimals).
    /// @param pricePerToken ETH price per 1e18 token units (i.e. per "whole" token).
    /// @return listingId    Assigned listing identifier.
    function listFraction(
        address tokenAddress,
        uint256 amount,
        uint256 pricePerToken
    ) external whenNotPaused returns (uint256 listingId) {
        if (tokenAddress == address(0)) revert ZeroAddress();
        if (amount == 0) revert ZeroAmount();
        if (pricePerToken == 0) revert ZeroPrice();

        // Pull tokens from seller into escrow (caller must approve first)
        IERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);

        listingId = _nextListingId++;
        _listings[listingId] = Listing({
            seller: msg.sender,
            tokenAddress: tokenAddress,
            amount: amount,
            pricePerToken: pricePerToken,
            active: true
        });

        emit Listed(listingId, msg.sender, tokenAddress, amount, pricePerToken);
    }

    /// @notice Purchase a listed batch of fraction tokens.
    /// @dev    Buyer must send exactly `totalCost()` wei.  Any dust is reverted.
    function buyFraction(uint256 listingId)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        Listing storage listing = _listings[listingId];
        if (!listing.active) revert ListingNotActive(listingId);

        // ── price calculation ──────────────────────────────────────────
        // totalPrice  = amount × pricePerToken / 1e18
        // platformFee = (totalPrice × platformFeeBps) / 10_000
        uint256 totalPrice = (listing.amount * listing.pricePerToken) / 1e18;
        uint256 fee = (totalPrice * platformFeeBps) / 10_000;
        uint256 sellerProceeds = totalPrice - fee;

        if (msg.value != totalPrice)
            revert IncorrectPayment(totalPrice, msg.value);

        listing.active = false;
        accruedFees += fee;

        // Interaction
        IERC20(listing.tokenAddress).safeTransfer(msg.sender, listing.amount);

        (bool ok, ) = listing.seller.call{value: sellerProceeds}("");
        if (!ok) revert ETHTransferFailed();

        emit Purchased(listingId, msg.sender, totalPrice, fee);
    }

    /// @notice Cancel a listing and reclaim escrowed tokens.
    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = _listings[listingId];
        if (!listing.active) revert ListingNotActive(listingId);
        if (listing.seller != msg.sender) revert NotSeller(listingId);

        listing.active = false;
        IERC20(listing.tokenAddress).safeTransfer(msg.sender, listing.amount);

        emit ListingCancelled(listingId);
    }

    // ─────────────────────────────────────────────── admin functions ──

    /// @notice Update the platform fee. Hard-capped at MAX_FEE_BPS (10 %).
    function updatePlatformFee(uint256 newFee) external onlyOwner {
        if (newFee > MAX_FEE_BPS) revert FeeTooHigh(MAX_FEE_BPS, newFee);
        emit PlatformFeeUpdated(platformFeeBps, newFee);
        platformFeeBps = newFee;
    }

    /// @notice Withdraw all accrued platform fees to `to`.
    function withdrawFees(address payable to) external onlyOwner nonReentrant {
        if (to == address(0)) revert ZeroAddress();
        uint256 amount = accruedFees;
        accruedFees = 0;
        (bool ok, ) = to.call{value: amount}("");
        if (!ok) revert ETHTransferFailed();
        emit FeesWithdrawn(to, amount);
    }

    /// @notice Pause the marketplace (disables listing and buying).
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the marketplace.
    function unpause() external onlyOwner {
        _unpause();
    }

    // ──────────────────────────────────────────────────── view helpers ──

    /// @notice Returns full listing data.
    function getListing(uint256 listingId)
        external
        view
        returns (Listing memory)
    {
        return _listings[listingId];
    }

    /// @notice Calculates the exact ETH a buyer must send for a listing.
    function totalCost(uint256 listingId)
        external
        view
        returns (uint256 total, uint256 fee, uint256 sellerProceeds)
    {
        Listing storage listing = _listings[listingId];
        total = (listing.amount * listing.pricePerToken) / 1e18;
        fee = (total * platformFeeBps) / 10_000;
        sellerProceeds = total - fee;
    }

    /// @notice Total listings ever created.
    function totalListings() external view returns (uint256) {
        return _nextListingId;
    }
}
