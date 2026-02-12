// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "./TokenSale.sol";
import "./VestingVault.sol";

contract LaunchpadFactory is ReentrancyGuard {
    struct CreateSaleParams {
        address raiseToken;
        address saleToken;
        address treasury;
        uint256 price;
        uint256 startTime;
        uint256 endTime;
        uint256 softCap;
        uint256 hardCap;
        uint256 vestingStart;
        uint256 vestingCliff;
        uint256 vestingDuration;
    }

    struct SaleInfo {
        address sale;
        address vault;
        address creator;
    }

    SaleInfo[] public sales;

    event SaleCreated(
        uint256 indexed saleId,
        address sale,
        address vault,
        address indexed creator
    );

    function createSale(
        CreateSaleParams calldata p
    ) external nonReentrant returns (address saleAddr, address vaultAddr) {
        VestingVault vault = new VestingVault(p.saleToken, address(this));

        TokenSale sale = new TokenSale(
            p.raiseToken,
            p.saleToken,
            p.treasury,
            p.price,
            p.startTime,
            p.endTime,
            p.softCap,
            p.hardCap,
            p.vestingStart,
            p.vestingCliff,
            p.vestingDuration,
            address(vault)
        );

        vault.transferOwnership(address(sale));
        sale.transferOwnership(msg.sender);

        saleAddr = address(sale);
        vaultAddr = address(vault);

        sales.push(SaleInfo({
            sale: saleAddr,
            vault: vaultAddr,
            creator: msg.sender
        }));

        emit SaleCreated(sales.length - 1, saleAddr, vaultAddr, msg.sender);
    }

    function salesCount() external view returns (uint256) {
        return sales.length;
    }

    function getSales() external view returns (SaleInfo[] memory) {
        return sales;
    }
}
