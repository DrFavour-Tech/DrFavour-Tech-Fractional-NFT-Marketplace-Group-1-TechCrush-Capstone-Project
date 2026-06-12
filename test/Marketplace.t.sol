// SPDX-License-Identifier: MIT
pragma solidity ^0.8.33;

import "forge-std/Test.sol";
import "../src/Marketplace.sol";
import "../src/FractionToken.sol";

contract MarketplaceTest is Test {
    Marketplace internal market;
    FractionToken internal ft;

    address internal owner = address(0x0000000000000000000000000000000000AAAAAa);
    address internal seller = address(0x0000000000000000000000000000000000cccCCc);
    address internal buyer = address(0x0000000000000000000000000000000000ddDddD);
    address internal feeTo = address(0x0000000000000000000000000000000000eEEEee);



    function setUp() public {
        market = new Marketplace(owner, 250); // 2.5%

        // Deploy a FractionToken owned by `seller` so seller can mint fractions for this test.
        ft = new FractionToken("Fraction", "FRAC", "Asset", seller);

        uint256 initial = 1_000e18;
        vm.startPrank(seller);
        ft.mint(seller, initial);
        vm.stopPrank();

        vm.deal(buyer, 100 ether);

    }

    function test_constructor_revertsOnZeroOwner() public {
        // Ownable(owner_) reverts with OwnableInvalidOwner(address(0)) before Marketplace's own ZeroAddress check
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new Marketplace(address(0), 0);
    }


    function test_constructor_revertsOnFeeTooHigh() public {
        uint256 maxBps = 1_000; // Marketplace.MAX_FEE_BPS
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.FeeTooHigh.selector,
                maxBps,
                maxBps + 1
            )
        );
        new Marketplace(owner, maxBps + 1);
    }


    function test_listFraction_happyPath_escrowsTokens() public {
        uint256 amount = 100e18;
        uint256 pricePerToken = 0.01 ether; // per 1e18 units

        vm.startPrank(seller);
        ft.approve(address(market), amount);
        uint256 listingId = market.listFraction(address(ft), amount, pricePerToken);
        vm.stopPrank();

        (Marketplace.Listing memory l) = market.getListing(listingId);

        assertEq(l.seller, seller);
        assertEq(l.tokenAddress, address(ft));
        assertEq(l.amount, amount);
        assertEq(l.pricePerToken, pricePerToken);
        assertTrue(l.active);

        // escrowed tokens held by market
        assertEq(ft.balanceOf(address(market)), amount);
        assertEq(ft.balanceOf(seller), 900e18);
    }

    function test_listFraction_revertsOnZeroTokenAddress() public {
        vm.startPrank(seller);
        vm.expectRevert(Marketplace.ZeroAddress.selector);
        market.listFraction(address(0), 1, 1);
        vm.stopPrank();
    }

    function test_listFraction_revertsOnZeroAmount() public {
        vm.startPrank(seller);
        vm.expectRevert(Marketplace.ZeroAmount.selector);
        market.listFraction(address(ft), 0, 1);
        vm.stopPrank();
    }

    function test_listFraction_revertsOnZeroPrice() public {
        vm.startPrank(seller);
        ft.approve(address(market), 1);
        vm.expectRevert(Marketplace.ZeroPrice.selector);
        market.listFraction(address(ft), 1, 0);
        vm.stopPrank();
    }

    function test_buyFraction_happyPath_transfersAndAccruesFees() public {
        uint256 amount = 100e18;
        uint256 pricePerToken = 0.01 ether;

        // list
        vm.startPrank(seller);
        ft.approve(address(market), amount);
        uint256 listingId = market.listFraction(address(ft), amount, pricePerToken);
        vm.stopPrank();

        (uint256 total, uint256 fee, uint256 sellerProceeds) = market.totalCost(listingId);
        assertEq(total, (amount * pricePerToken) / 1e18);
        assertEq(fee, (total * market.platformFeeBps()) / 10_000);
        assertEq(sellerProceeds, total - fee);

        uint256 sellerBalBefore = seller.balance;
        uint256 feeToBalBefore_ = owner.balance;

        vm.startPrank(buyer);
        market.buyFraction{value: total}(listingId);
        vm.stopPrank();

        // listing inactive
        (Marketplace.Listing memory l2) = market.getListing(listingId);
        assertFalse(l2.active);

        // buyer receives tokens
        assertEq(ft.balanceOf(buyer), amount);
        // escrow emptied
        assertEq(ft.balanceOf(address(market)), 0);

        // seller paid
        assertEq(seller.balance, sellerBalBefore + sellerProceeds);

        // accrued fee tracked
        assertEq(market.accruedFees(), fee);

        // owner hasn't withdrawn yet
        assertEq(owner.balance, feeToBalBefore_);
    }

    function test_buyFraction_revertsOnWrongPayment() public {
        uint256 amount = 10e18;
        uint256 pricePerToken = 0.02 ether;

        vm.startPrank(seller);
        ft.approve(address(market), amount);
        uint256 listingId = market.listFraction(address(ft), amount, pricePerToken);
        vm.stopPrank();

        (, uint256 fee, uint256 sellerProceeds) = market.totalCost(listingId);

        uint256 total = (amount * pricePerToken) / 1e18;
        uint256 wrong = total + 1 wei;

        vm.startPrank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.IncorrectPayment.selector, total, wrong));
        market.buyFraction{value: wrong}(listingId);
        vm.stopPrank();


        // ensure still active
        (Marketplace.Listing memory l2) = market.getListing(listingId);
        assertTrue(l2.active);
        assertEq(market.accruedFees(), 0);
    }

    function test_buyFraction_revertsWhenListingInactive() public {
        uint256 amount = 10e18;
        uint256 pricePerToken = 0.02 ether;

        vm.startPrank(seller);
        ft.approve(address(market), amount);
        uint256 listingId = market.listFraction(address(ft), amount, pricePerToken);
        vm.stopPrank;

        (uint256 total,,) = market.totalCost(listingId);
        vm.startPrank(buyer);
        market.buyFraction{value: total}(listingId);

        vm.expectRevert(abi.encodeWithSelector(Marketplace.ListingNotActive.selector, listingId));
        market.buyFraction{value: total}(listingId);
        vm.stopPrank();

    }

    function test_cancelListing_happyPath_onlySeller() public {
        uint256 amount = 50e18;
        uint256 pricePerToken = 0.01 ether;

        vm.startPrank(seller);
        ft.approve(address(market), amount);
        uint256 listingId = market.listFraction(address(ft), amount, pricePerToken);
        vm.stopPrank();

        vm.startPrank(buyer);
        vm.expectRevert(abi.encodeWithSelector(Marketplace.NotSeller.selector, listingId));
        market.cancelListing(listingId);
        vm.stopPrank();

        vm.prank(seller);
        market.cancelListing(listingId);


        (Marketplace.Listing memory l2) = market.getListing(listingId);
        assertFalse(l2.active);
        assertEq(ft.balanceOf(seller), 1000e18);
        assertEq(ft.balanceOf(address(market)), 0);
    }

    function test_updatePlatformFee_happyPath_and_cap() public {
        vm.startPrank(owner);
        market.updatePlatformFee(1000); // exactly cap
        assertEq(market.platformFeeBps(), 1000);

        vm.expectRevert(abi.encodeWithSelector(Marketplace.FeeTooHigh.selector, market.MAX_FEE_BPS(), 1001));
        market.updatePlatformFee(1001);
        vm.stopPrank();
    }


    function test_withdrawFees_happyPath() public {

        // manually set accrued via listing purchase
        uint256 amount = 100e18;
        uint256 pricePerToken = 0.01 ether;
        vm.startPrank(seller);
        ft.approve(address(market), amount);
        uint256 listingId = market.listFraction(address(ft), amount, pricePerToken);
        vm.stopPrank();

        (uint256 total, uint256 fee,) = market.totalCost(listingId);
        vm.prank(buyer);
        market.buyFraction{value: total}(listingId);

        uint256 ownerBalBefore = owner.balance;
        uint256 feeBal = fee;

        vm.prank(owner);
        market.withdrawFees(payable(owner));


        assertEq(market.accruedFees(), 0);
        assertEq(owner.balance, ownerBalBefore + feeBal);
    }

    function test_pause_unpause_disablesCore() public {
        uint256 amount = 10e18;
        uint256 pricePerToken = 0.02 ether;

        vm.startPrank(seller);
        ft.approve(address(market), amount);
        uint256 listingId = market.listFraction(address(ft), amount, pricePerToken);
        vm.stopPrank();

        vm.prank(owner);
        market.pause();


        // cannot cancel? cancelListing is not whenNotPaused in contract; it will still work.
        // but buyFraction should revert.
        (uint256 totalCost_, uint256 fee_, uint256 sellerProceeds_) = market.totalCost(listingId);


        uint256 expectedTotal = (amount * pricePerToken) / 1e18;
        // Sanity: totalCost() should match our expected math
        assertEq(totalCost_, expectedTotal);
        vm.prank(buyer);
        vm.expectRevert();
        market.buyFraction{value: expectedTotal}(listingId);

        vm.prank(owner);
        market.unpause();
        vm.prank(buyer);
        // after unpause, buyFraction should succeed with the same expectedTotal
        market.buyFraction{value: expectedTotal}(listingId);

    }
}

