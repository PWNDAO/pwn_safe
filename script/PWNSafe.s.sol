// SPDX-License-Identifier: LGPL-3.0-only
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
--rpc-url $RINKEBY_URL \
--private-key $DEPLOY_PRIVATE_KEY_TESTNET \
--broadcast
 */

contract Deploy is Script {

	function run() external {
		if (block.chainid == 1)
			deployMainnet();
		else if (block.chainid == 5)
			deployGoerli();
		else if (block.chainid == 31337)
			deployLocal();
	}


	function deployMainnet() private {
		// TODO:
	}

	function deployGoerli() private {
		deploy(
			address(0x01), // TODO:
			address(0x3E5c63644E683549055b9Be8653de26E0B4CD36E),
			address(0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2),
			address(0x04) // TODO:
		);
	}

	function deployLocal() private {
		deploy(
			address(0x01),
			address(0x02),
			address(0x03),
			address(0x04)
		);
	}


	function deploy(
		address owner,
		address gnosisSafeSingleton,
		address gnosisSafeFactory,
		address gnosisFallbackHandler
	) private {
		vm.startBroadcast();

		// 1. Deploy ATR contract
		AssetTransferRights atr = new AssetTransferRights();

		// 2. Deploy ATR Guard logic
		AssetTransferRightsGuard guardLogic = new AssetTransferRightsGuard();

		// 3. Deploye ATR Guard proxy with ATR Guard logic
		AssetTransferRightsGuardProxy guardProxy = new AssetTransferRightsGuardProxy(
			address(guardLogic), owner
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

		vm.stopBroadcast();
	}

}
