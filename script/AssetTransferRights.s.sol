// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "../src/AssetTransfeRights.sol";


contract Deploy is Script {

	function run() external {
		vm.startBroadcast();

        new AssetTransfeRights();

        vm.stopBroadcast();
	}

}