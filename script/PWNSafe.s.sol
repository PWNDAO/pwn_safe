// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "forge-std/Script.sol";

import "@pwn-safe/factory/PWNSafeFactory.sol";
import "@pwn-safe/guard/AssetTransferRightsGuard.sol";
import "@pwn-safe/guard/AssetTransferRightsGuardProxy.sol";
import "@pwn-safe/guard/OperatorsContext.sol";
import "@pwn-safe/handler/CompatibilityFallbackHandler.sol";
import "@pwn-safe/module/AssetTransferRights.sol";
import "@pwn-safe/Whitelist.sol";

/*
Deploy PWNSafe contracts by executing commands:

source .env

forge script script/PWNSafe.s.sol:Deploy \
--sig "deploy(address,address,address)" $ADMIN $WHITELIST $HANDLER \
--rpc-url $RPC_URL \
--private-key $DEPLOY_PRIVATE_KEY \
--with-gas-price $(cast --to-wei 10 gwei) \
--verify --etherscan-api-key $ETHERSCAN_API_KEY \
--broadcast
*/
contract Deploy is Script {

	function deployWhitelist() external {
		vm.startBroadcast();

		Whitelist whitelist = new Whitelist();
		console2.log("Whitelist address:", address(whitelist));

		vm.stopBroadcast();
	}

	function deployFallbackHandler(address whitelist) external {
		vm.startBroadcast();

		CompatibilityFallbackHandler handler = new CompatibilityFallbackHandler(whitelist);
		console2.log("CompatibilityFallbackHandler address:", address(handler));

		vm.stopBroadcast();
	}

	function deploy(
		address admin,
		address whitelist,
		address gnosisFallbackHandler
	) external {
		vm.startBroadcast();

		address gnosisSafeSingleton = address(0x3E5c63644E683549055b9Be8653de26E0B4CD36E);
		address gnosisSafeFactory = address(0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2);

		// 1. Deploy ATR contract
		AssetTransferRights atr = new AssetTransferRights(whitelist);
		console2.log("AssetTransferRights address:", address(atr));

		// 2. Deploy ATR guard logic
		AssetTransferRightsGuard guardLogic = new AssetTransferRightsGuard();
		console2.log("AssetTransferRightsGuard address:", address(guardLogic));

		// 3. Deploye ATR Guard proxy with ATR Guard logic
		AssetTransferRightsGuardProxy guardProxy = new AssetTransferRightsGuardProxy(
			address(guardLogic), admin
		);
		console2.log("AssetTransferRightsGuardProxy address:", address(guardProxy));

		// 4. Initialized ATR Guard proxy as ATR Guard
		AssetTransferRightsGuard(address(guardProxy)).initialize(address(atr));

		// 5. Deploy PWNSafe factory
		PWNSafeFactory factory = new PWNSafeFactory(
			gnosisSafeSingleton,
			gnosisSafeFactory,
			address(gnosisFallbackHandler),
			address(atr),
			address(guardProxy)
		);
		console2.log("PWNSafeFactory address:", address(factory));

		// 6. Initialize ATR contract
		atr.initialize(address(factory), address(guardProxy));

		vm.stopBroadcast();
	}

}
