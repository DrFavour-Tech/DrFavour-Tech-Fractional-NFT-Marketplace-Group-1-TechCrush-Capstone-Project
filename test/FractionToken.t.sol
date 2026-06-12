// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";
import "../src/FractionToken.sol";

contract FractionTokenTest is Test {
    address internal vault = address(0x0000000000000000000000000000000000AAAAAa);
    address internal owner = address(0x0000000000000000000000000000000000dEAd00);
    address internal user = address(0x0000000000000000000000000000000000000B0b);


    function test_constructor_setsAssetNameAndOwner() public {
        FractionToken ft = new FractionToken("Name", "SYM", "AssetName", vault);
        assertEq(ft.assetName(), "AssetName");
        assertEq(ft.owner(), vault);
        assertEq(ft.name(), "Name");
        assertEq(ft.symbol(), "SYM");
    }

    function test_constructor_revertsOnZeroVault() public {
        // Ownable(vault_) reverts with OwnableInvalidOwner(address(0)) before FractionToken's own ZeroAddress check
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new FractionToken("N", "S", "A", address(0));
    }


    function test_mint_onlyOwner() public {
        FractionToken ft = new FractionToken("N", "S", "A", vault);

        vm.expectRevert();
        vm.prank(user);
        ft.mint(user, 1);
    }

    function test_mint_revertsOnZeroTo() public {
        FractionToken ft = new FractionToken("N", "S", "A", vault);
        vm.prank(vault);
        vm.expectRevert(FractionToken.ZeroAddress.selector);
        ft.mint(address(0), 1);
    }

    function test_mint_revertsOnZeroAmount() public {
        FractionToken ft = new FractionToken("N", "S", "A", vault);
        vm.prank(vault);
        vm.expectRevert(FractionToken.ZeroAmount.selector);
        ft.mint(user, 0);
    }

    function test_mint_success_mintsToReceiver() public {
        FractionToken ft = new FractionToken("N", "S", "A", vault);
        uint256 amt = 1e18;

        vm.prank(vault);
        ft.mint(user, amt);

        assertEq(ft.balanceOf(user), amt);
        assertEq(ft.totalSupply(), amt);
    }

    function test_burn_onlyOwner() public {
        FractionToken ft = new FractionToken("N", "S", "A", vault);
        uint256 amt = 100;

        vm.prank(vault);
        ft.mint(user, amt);

        vm.expectRevert();
        vm.prank(user);
        ft.burn(user, 1);
    }

    function test_burn_revertsOnZeroFrom() public {
        FractionToken ft = new FractionToken("N", "S", "A", vault);
        vm.prank(vault);
        vm.expectRevert(FractionToken.ZeroAddress.selector);
        ft.burn(address(0), 1);
    }

    function test_burn_revertsOnZeroAmount() public {
        FractionToken ft = new FractionToken("N", "S", "A", vault);
        vm.prank(vault);
        vm.expectRevert(FractionToken.ZeroAmount.selector);
        ft.burn(user, 0);
    }

    function test_burn_success_decreasesBalanceAndSupply() public {
        FractionToken ft = new FractionToken("N", "S", "A", vault);
        uint256 amt = 1000;

        vm.prank(vault);
        ft.mint(user, amt);
        assertEq(ft.balanceOf(user), amt);

        vm.prank(vault);
        ft.burn(user, 250);

        assertEq(ft.balanceOf(user), 750);
        assertEq(ft.totalSupply(), 750);
    }
}

