// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {LaunchpadFactory} from "../src/LaunchpadFactory.sol";

contract DeployLaunchpadScript is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        address raiseToken = vm.envAddress("RAISE_TOKEN");
        address saleToken = vm.envAddress("SALE_TOKEN");
        address treasury = vm.envAddress("TREASURY");
        uint256 price = vm.envUint("PRICE");
        uint256 startTime = vm.envUint("START_TIME");
        uint256 endTime = vm.envUint("END_TIME");
        uint256 softCap = vm.envUint("SOFT_CAP");
        uint256 hardCap = vm.envUint("HARD_CAP");
        uint256 vestingStart = vm.envUint("VESTING_START");
        uint256 vestingCliff = vm.envUint("VESTING_CLIFF");
        uint256 vestingDuration = vm.envUint("VESTING_DURATION");

        vm.startBroadcast(deployerKey);

        LaunchpadFactory factory = new LaunchpadFactory();
        LaunchpadFactory.CreateSaleParams memory p = LaunchpadFactory.CreateSaleParams({
            raiseToken: raiseToken,
            saleToken: saleToken,
            treasury: treasury,
            price: price,
            startTime: startTime,
            endTime: endTime,
            softCap: softCap,
            hardCap: hardCap,
            vestingStart: vestingStart,
            vestingCliff: vestingCliff,
            vestingDuration: vestingDuration
        });

        (address sale, address vault) = factory.createSale(p);

        vm.stopBroadcast();

        console2.log("Factory:", address(factory));
        console2.log("Sale:", sale);
        console2.log("Vault:", vault);
    }
}
