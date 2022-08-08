// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "safe-contracts/base/ModuleManager.sol";
import "safe-contracts/common/StorageAccessible.sol";
import "safe-contracts/proxies/GnosisSafeProxy.sol";


/// TODO: Doc
contract GnosisSafeManager {

	/*----------------------------------------------------------*|
	|*  # VARIABLES & CONSTANTS DEFINITIONS                     *|
	|*----------------------------------------------------------*/

	uint256 constant internal GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;
	uint256 constant internal FALLBACK_HANDLER_STORAGE_SLOT = 0x6c9a6c4a39284e37ed1cf53d337577d14212a4870fb976a4366c693b939918d5;
	address constant internal SENTINEL_MODULES = address(0x1);

	// mainnet 0xd9Db270c1B5E3Bd161E8c8503c55cEABeE709552
	address immutable internal GNOSIS_SAFE_SINGLETON_ADDRESS;
	address immutable internal FALLBACK_HANDLER_ADDRESS;


	/*----------------------------------------------------------*|
	|*  # CONSTRUCTOR                                           *|
	|*----------------------------------------------------------*/

	constructor(address safeSingletonAddress, address fallbackHandlerAddress) {
		GNOSIS_SAFE_SINGLETON_ADDRESS = safeSingletonAddress;
		FALLBACK_HANDLER_ADDRESS = fallbackHandlerAddress;
	}


	/*----------------------------------------------------------*|
	|*  # GNOSIS SAFE CHECKS                                    *|
	|*----------------------------------------------------------*/

	/// TODO: Doc
	function _isSafeInCorrectState(address safe, address atrGuard, address atrModule) internal view returns (bool) {
		// Check that address is GnosisSafeProxy
		// Need to hash bytes arrays first, because solidity cannot compare byte arrays directly
		if (keccak256(type(GnosisSafeProxy).runtimeCode) != keccak256(address(safe).code))
			return false;

		// TODO: List of supported singletons?
		// Check that proxy has correct singleton set
		bytes memory singletonValue = StorageAccessible(safe).getStorageAt(0, 1);
		if (bytes32(singletonValue) != bytes32(bytes20(GNOSIS_SAFE_SINGLETON_ADDRESS)))
			return false;

		// Check that safe has correct guard set
		bytes memory guardValue = StorageAccessible(safe).getStorageAt(GUARD_STORAGE_SLOT, 1);
		if (bytes32(guardValue) != bytes32(bytes20(atrGuard)))
			return false;

		// Check that safe has correct module set
		if (ModuleManager(safe).isModuleEnabled(atrModule) == false)
			return false;

		// Check that safe has only one module
		(address[] memory modules, ) = ModuleManager(safe).getModulesPaginated(SENTINEL_MODULES, 2);
		if (modules.length > 1)
			return false;

		// Check that safe has correct fallback handler set
		bytes memory fallbackHandlerValue = StorageAccessible(safe).getStorageAt(FALLBACK_HANDLER_STORAGE_SLOT, 1);
		if (bytes32(fallbackHandlerValue) != bytes32(bytes20(FALLBACK_HANDLER_ADDRESS)))
			return false;

		// All checks passes
		return true;
	}

}
