// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Script.sol";
import "../src/AssetTransferRights.sol";


/*
Deploy AssetTransferRights contract by executing commands:

source .env
forge script script/AssetTransferRights.s.sol:Deploy \
--rpc-url $RINKEBY_URL \
--private-key $DEPLOY_PRIVATE_KEY_TESTNET \
--broadcast
 */

contract Deploy is Script {

	function run() external {
		vm.startBroadcast();

		// TODO:
        new AssetTransferRights(address(0x1), address(0x2));

        vm.stopBroadcast();
	}

}
