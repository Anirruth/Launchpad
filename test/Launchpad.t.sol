// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LaunchpadFactory} from "../src/LaunchpadFactory.sol";
import {TokenSale} from "../src/TokenSale.sol";
import {VestingVault} from "../src/VestingVault.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name_, string memory symbol_) ERC20(name_, symbol_) {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract LaunchpadTest is Test {
    LaunchpadFactory internal factory;
    MockERC20 internal raiseToken;
    MockERC20 internal saleToken;

    address internal creator = address(0xA11CE);
    address internal buyer = address(0xB0B);
    address internal treasury = address(0xCAFE);

    uint256 internal constant PRICE = 2e18;

    function setUp() public {
        factory = new LaunchpadFactory();
        raiseToken = new MockERC20("Raise", "RAISE");
        saleToken = new MockERC20("Sale", "SALE");
    }

    function _createSale(
        uint256 softCap,
        uint256 hardCap
    ) internal returns (TokenSale sale, VestingVault vault, uint256 startTime, uint256 endTime) {
        startTime = block.timestamp + 10;
        endTime = startTime + 100;

        LaunchpadFactory.CreateSaleParams memory p = LaunchpadFactory.CreateSaleParams({
            raiseToken: address(raiseToken),
            saleToken: address(saleToken),
            treasury: treasury,
            price: PRICE,
            startTime: startTime,
            endTime: endTime,
            softCap: softCap,
            hardCap: hardCap,
            vestingStart: endTime + 10,
            vestingCliff: endTime + 20,
            vestingDuration: 200
        });

        vm.prank(creator);
        (address saleAddr, address vaultAddr) = factory.createSale(p);

        sale = TokenSale(saleAddr);
        vault = VestingVault(vaultAddr);
    }

    function testCreateSaleSetsOwners() public {
        (TokenSale sale, VestingVault vault,,) = _createSale(100e18, 1_000e18);
        assertEq(sale.owner(), creator);
        assertEq(vault.owner(), address(sale));
        assertEq(factory.salesCount(), 1);
    }

    function testSuccessfulSaleClaimAndVest() public {
        (TokenSale sale, VestingVault vault, uint256 startTime, uint256 endTime) = _createSale(100e18, 1_000e18);

        uint256 raiseAmount = 200e18;
        uint256 tokenAmount = (raiseAmount * 1e18) / PRICE;

        saleToken.mint(address(vault), tokenAmount);
        raiseToken.mint(buyer, raiseAmount);

        vm.startPrank(buyer);
        raiseToken.approve(address(sale), raiseAmount);
        vm.warp(startTime + 1);
        sale.buy(raiseAmount);
        vm.stopPrank();

        vm.warp(endTime + 1);
        vm.prank(creator);
        sale.finalize();

        assertEq(raiseToken.balanceOf(treasury), raiseAmount);

        vm.prank(buyer);
        sale.claimTokens();

        (uint256 total,, uint256 vestStart, uint256 cliff, uint256 duration) = vault.vestings(buyer);
        assertEq(total, tokenAmount);
        assertEq(vestStart, endTime + 10);
        assertEq(cliff, endTime + 20);
        assertEq(duration, 200);

        vm.warp(endTime + 30);
        uint256 beforeBal = saleToken.balanceOf(buyer);
        vm.prank(buyer);
        vault.claim();
        uint256 afterBal = saleToken.balanceOf(buyer);
        assertGt(afterBal, beforeBal);
    }

    function testRefundWhenSaleFails() public {
        (TokenSale sale,, uint256 startTime, uint256 endTime) = _createSale(300e18, 1_000e18);

        uint256 raiseAmount = 100e18;
        raiseToken.mint(buyer, raiseAmount);

        vm.startPrank(buyer);
        raiseToken.approve(address(sale), raiseAmount);
        vm.warp(startTime + 1);
        sale.buy(raiseAmount);
        vm.stopPrank();

        vm.warp(endTime + 1);
        vm.prank(creator);
        sale.finalize();

        assertTrue(sale.saleFailed());

        uint256 beforeBal = raiseToken.balanceOf(buyer);
        vm.prank(buyer);
        sale.refund();
        uint256 afterBal = raiseToken.balanceOf(buyer);
        assertEq(afterBal - beforeBal, raiseAmount);
    }

    function testFinalizeRevertsWhenVaultUnderfunded() public {
        (TokenSale sale,, uint256 startTime, uint256 endTime) = _createSale(100e18, 1_000e18);

        uint256 raiseAmount = 200e18;
        raiseToken.mint(buyer, raiseAmount);

        vm.startPrank(buyer);
        raiseToken.approve(address(sale), raiseAmount);
        vm.warp(startTime + 1);
        sale.buy(raiseAmount);
        vm.stopPrank();

        vm.warp(endTime + 1);
        vm.prank(creator);
        vm.expectRevert("Insufficient sale token liquidity");
        sale.finalize();
    }
}
