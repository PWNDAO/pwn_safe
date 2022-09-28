// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "forge-std/Script.sol";

import "../src/factory/PWNSafeFactory.sol";
import "../src/guard/AssetTransferRightsGuard.sol";
import "../src/guard/AssetTransferRightsGuardProxy.sol";
import "../src/guard/OperatorsContext.sol";
import "../src/AssetTransferRights.sol";


/*
Deploy PWNSafe contracts by executing commands:

source .env

forge script script/PWNSafe.s.sol:Deploy \
--rpc-url $RPC_URL \
--private-key $DEPLOY_PRIVATE_KEY \
--with-gas-price $(cast --to-wei 10 gwei) \
--verify --etherscan-api-key $ETHERSCAN_API_KEY \
--broadcast
*/
contract Deploy is Script {

	function run() external {
		vm.startBroadcast();

		deploy(
			address(0x0), // Fill admin
			address(0x3E5c63644E683549055b9Be8653de26E0B4CD36E),
			address(0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2),
			address(0xF97779f08Fa2f952eFb12F5827Ad95cE26fEF432)
		);

		vm.stopBroadcast();
	}


	function deploy(
		address admin,
		address gnosisSafeSingleton,
		address gnosisSafeFactory,
		address gnosisFallbackHandler
	) private {
		// 1. Deploy ATR contract
		AssetTransferRights atr = new AssetTransferRights();

		// 2. Deploy ATR Guard logic
		AssetTransferRightsGuard guardLogic = new AssetTransferRightsGuard();

		// 3. Deploye ATR Guard proxy with ATR Guard logic
		AssetTransferRightsGuardProxy guardProxy = new AssetTransferRightsGuardProxy(
			address(guardLogic), admin
		);

		// 4. Deploy Operators Context
		OperatorsContext operatorsContext = new OperatorsContext(address(guardProxy));

		// 5. Initialized ATR Guard proxy as ATR Guard
		AssetTransferRightsGuard(address(guardProxy)).initialize(address(atr), address(operatorsContext));

		// 6. Deploy PWNSafe factory
		PWNSafeFactory factory = new PWNSafeFactory(
			gnosisSafeSingleton,
			gnosisSafeFactory,
			gnosisFallbackHandler,
			address(atr),
			address(guardProxy)
		);

		// 7. Set guard address to ATR contract
		atr.setAssetTransferRightsGuard(address(guardProxy));

		// 8. Set PWNSafe validator to ATR contract
		atr.setPWNSafeValidator(address(factory));
	}

}
