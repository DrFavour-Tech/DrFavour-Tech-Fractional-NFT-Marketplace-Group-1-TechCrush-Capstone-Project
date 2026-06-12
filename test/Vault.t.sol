// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";
import "./MockERC721.sol";
import "../src/Vault.sol";
import "../src/FractionToken.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract VaultTest is Test {
    Vault internal vault;
    MockERC721 internal nft;

    address internal owner = address(0xA11CE);
    address internal user = address(0xB0B);

    function setUp() public {
        nft = new MockERC721("Mock", "MOCK");
        vault = new Vault(owner);
    }

    function test_constructor_revertsOnZeroOwner() public {
        // Ownable(owner_) reverts with OwnableInvalidOwner(address(0)) before Vault's own ZeroAddress check
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new Vault(address(0));
    }


    function test_deposit_happyPath_createsVaultAndFractionToken() public {
        uint256 tokenId = 1;
        uint256 fractionSupply = 123;

        nft.mint(user, tokenId);
        vm.prank(user);
        nft.approve(address(vault), tokenId);

        vm.prank(user);
        uint256 vaultId = vault.deposit(
            address(nft),
            tokenId,
            fractionSupply,
            "Fraction: Mock #1",
            "fMOCK1"
        );

        assertEq(vaultId, 0);
        assertEq(vault.totalVaults(), 1);

        // vaulted flag
        bool vaulted = vault.isVaulted(address(nft), tokenId);
        assertTrue(vaulted);

        // locked nft details
        (Vault.LockedNFT memory locked) = vault.getLockedNFT(vaultId);
        assertEq(locked.nftContract, address(nft));
        assertEq(locked.tokenId, tokenId);
        assertEq(locked.depositor, user);
        assertEq(locked.fractionSupply, fractionSupply);
        assertTrue(locked.active);

        // fraction token minted to depositor
        assertEq(locked.fractionToken, vault.getLockedNFT(vaultId).fractionToken);
        // balance should be fractionSupply * 1e18
        uint256 expected = fractionSupply * 1e18;
        assertEq(IERC20(locked.fractionToken).balanceOf(user), expected);
    }

    function test_deposit_revertsOnZeroNftContract() public {
        nft.mint(user, 1);
        vm.prank(user);
        nft.approve(address(vault), 1);

        vm.prank(user);
        vm.expectRevert(Vault.ZeroAddress.selector);
        vault.deposit(address(0), 1, 1, "N", "S");
    }

    function test_deposit_revertsOnZeroFractionSupply() public {
        uint256 tokenId = 1;
        nft.mint(user, tokenId);
        vm.prank(user);
        nft.approve(address(vault), tokenId);

        vm.prank(user);
        vm.expectRevert(Vault.ZeroSupply.selector);
        vault.deposit(address(nft), tokenId, 0, "N", "S");
    }

    function test_deposit_revertsOnAlreadyVaultedTokenId() public {
        uint256 tokenId = 1;
        uint256 fractionSupply = 1;

        nft.mint(user, tokenId);
        vm.startPrank(user);
        nft.approve(address(vault), tokenId);
        vault.deposit(address(nft), tokenId, fractionSupply, "A", "a");

        // second deposit same nft+tokenId
        vm.expectRevert(abi.encodeWithSelector(Vault.AlreadyVaulted.selector, tokenId));
        vault.deposit(address(nft), tokenId, fractionSupply, "B", "b");
        vm.stopPrank
        ;
    }

    function test_getLockedNFT_revertsOnInvalidVaultId() public {
        vm.expectRevert(abi.encodeWithSelector(Vault.VaultNotFound.selector, 7));
        vault.getLockedNFT(7);
    }
}




