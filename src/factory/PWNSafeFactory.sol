// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "safe-contracts/proxies/GnosisSafeProxyFactory.sol";
import "safe-contracts/proxies/GnosisSafeProxy.sol";
import "safe-contracts/GnosisSafe.sol";

import "./IPWNSafeValidator.sol";


contract PWNSafeFactory is IPWNSafeValidator {

	/*----------------------------------------------------------*|
	|*  # VARIABLES & CONSTANTS DEFINITIONS                     *|
	|*----------------------------------------------------------*/

	string public constant VERSION = "0.1.0";

	bytes32 internal constant GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;
	address internal constant SENTINEL_MODULES = address(0x1);

	address internal immutable pwnFactorySingleton;
	address internal immutable gnosisSafeSingleton;
	GnosisSafeProxyFactory internal immutable gnosisSafeProxyFactory;
	address internal immutable fallbackHandler;
	address internal immutable atrModule;
	address internal immutable atrGuard;

	mapping (address => bool) public isValidSafe;


	/*----------------------------------------------------------*|
	|*  # CONSTRUCTOR                                           *|
	|*----------------------------------------------------------*/

	constructor(
		address _gnosisSafeSingleton,
		address _gnosisSafeProxyFactory,
		address _fallbackHandler,
		address _atrModule,
		address _atrGuard
	) {
		pwnFactorySingleton = address(this);
		gnosisSafeSingleton = _gnosisSafeSingleton;
		gnosisSafeProxyFactory = GnosisSafeProxyFactory(_gnosisSafeProxyFactory);
		fallbackHandler = _fallbackHandler;
		atrModule = _atrModule;
		atrGuard = _atrGuard;
	}


	/*----------------------------------------------------------*|
	|*  # DEPLOY PROXY                                          *|
	|*----------------------------------------------------------*/

	function deployProxy(
		address[] calldata owners,
		uint256 threshold
	) external returns (GnosisSafe) {
		// Deploy new gnosis safe proxy
		GnosisSafeProxy proxy = gnosisSafeProxyFactory.createProxy(gnosisSafeSingleton, "");
		GnosisSafe safe = GnosisSafe(payable(address(proxy)));

		// Setup safe
		safe.setup(
			owners, // _owners
			threshold, // _threshold
			address(this), // to
			abi.encodeWithSelector(PWNSafeFactory.setupNewSafe.selector), // data
			fallbackHandler, // fallbackHandler
			address(0), // paymentToken
			0, // payment
			payable(address(0)) // paymentReceiver
		);

		// Store as valid address
		isValidSafe[address(safe)] = true;

		return safe;
	}


	/*----------------------------------------------------------*|
	|*  # NEW SAFE SETUP                                        *|
	|*----------------------------------------------------------*/

	function setupNewSafe() external {
		// Check that is called via delegatecall
		require(address(this) != pwnFactorySingleton, "Should only be called via delegatecall");

		// Check that caller is GnosisSafeProxy
		// Need to hash bytes arrays first, because solidity cannot compare byte arrays directly
		require(keccak256(type(GnosisSafeProxy).runtimeCode) == keccak256(address(this).code), "Caller is not gnosis safe proxy");

		// Check that proxy has correct singleton set
		// GnosisSafeStorage.sol defines singleton address at the first position (-> index 0)
		bytes memory singletonValue = StorageAccessible(address(this)).getStorageAt(0, 1);
		require(bytes32(singletonValue) == bytes32(uint256(uint160(gnosisSafeSingleton))), "Proxy has unsupported singleton");

		_storeGuardAndModule();
	}

	function _storeGuardAndModule() private {
		// GnosisSafeStorage.sol defines modules mapping at the second position (-> index 1)
		bytes32 atrModuleSlot = keccak256(abi.encode(atrModule, uint256(1)));
		address atrModuleAddress = atrModule;

		// GnosisSafeStorage.sol defines modules mapping at the second position (-> index 1)
		bytes32 sentinelSlot = keccak256(abi.encode(SENTINEL_MODULES, uint256(1)));
		address sentinelAddress = SENTINEL_MODULES;

		bytes32 guardSlot = GUARD_STORAGE_SLOT;
		address atrGuardAddress = atrGuard;

		assembly {
			// Enable new module
			sstore(sentinelSlot, atrModuleAddress) // SENTINEL_MODULES key should have value of module address
			sstore(atrModuleSlot, sentinelAddress) // module address key should have value of SENTINEL_MODULES

			// Set guard
			sstore(guardSlot, atrGuardAddress)
		}
	}

}
