// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "forge-std/Test.sol";

import "openzeppelin-contracts/contracts/interfaces/IERC165.sol";

import "safe-contracts/proxies/GnosisSafeProxyFactory.sol";
import "safe-contracts/proxies/GnosisSafeProxy.sol";
import "safe-contracts/GnosisSafe.sol";

import "../../src/factory/PWNSafeFactory.sol";
import "../../src/guard/AssetTransferRightsGuard.sol";
import "../../src/guard/AssetTransferRightsGuardProxy.sol";
import "../../src/guard/OperatorsContext.sol";
import "../../src/handler/DefaultCallbackHandler.sol";
import "../../src/AssetTransferRights.sol";


contract Integration_Test is Test {

	address constant admin = address(0x8ea42a3334E2AaB7d144990FDa6afE67a85E2a5c);
	address constant erc1820Registry = address(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);
	GnosisSafe gnosisSafeSingleton;
	GnosisSafeProxyFactory gnosisSafeFactory;
	DefaultCallbackHandler gnosisFallbackHandler;

	address immutable owner = address(0x1001);

	AssetTransferRights atr;
	OperatorsContext operatorsContext;
	PWNSafeFactory factory;
	GnosisSafe safe;

	constructor() {
		// Mock ERC1820 Registry
		vm.etch(erc1820Registry, bytes("data"));
		vm.mockCall(
			erc1820Registry,
			abi.encodeWithSignature("getInterfaceImplementer(address,bytes32)"),
			abi.encode(address(0))
		);

		// Goerli testnet
		if (block.chainid == 5) {
			gnosisSafeSingleton = GnosisSafe(payable(0x3E5c63644E683549055b9Be8653de26E0B4CD36E));
			gnosisSafeFactory = GnosisSafeProxyFactory(0xa6B71E26C5e0845f74c812102Ca7114b6a896AB2);
			// Custom deployment of `DefaultCallbackHandler`
			gnosisFallbackHandler = DefaultCallbackHandler(0xF97779f08Fa2f952eFb12F5827Ad95cE26fEF432);
		}
		// Local devnet
		else if (block.chainid == 31337) {
			gnosisSafeSingleton = new GnosisSafe();
			gnosisSafeFactory = new GnosisSafeProxyFactory();
			gnosisFallbackHandler = new DefaultCallbackHandler();
		}
	}

	function setUp() public virtual {
		_deployRealm();

		address[] memory owners = new address[](1);
		owners[0] = owner;
		safe = factory.deployProxy(owners, 1);
	}

	function _deployRealm() private {
		// 1. Deploy ATR contract
		atr = new AssetTransferRights();

		// 2. Deploy ATR Guard logic
		AssetTransferRightsGuard guardLogic = new AssetTransferRightsGuard();

		// 3. Deploye ATR Guard proxy with ATR Guard logic
		AssetTransferRightsGuardProxy guardProxy = new AssetTransferRightsGuardProxy(
			address(guardLogic), admin
		);

		// 4. Deploy Operators Context
		operatorsContext = new OperatorsContext(address(guardProxy));

		// 5. Initialized ATR Guard proxy as ATR Guard
		AssetTransferRightsGuard(address(guardProxy)).initialize(address(atr), address(operatorsContext));

		// 6. Deploy PWNSafe factory
		factory = new PWNSafeFactory(
			address(gnosisSafeSingleton),
			address(gnosisSafeFactory),
			address(gnosisFallbackHandler),
			address(atr),
			address(guardProxy)
		);

		// 7. Set guard address to ATR contract
		atr.setAssetTransferRightsGuard(address(guardProxy));

		// 8. Set PWNSafe validator to ATR contract
		atr.setPWNSafeValidator(address(factory));
	}


	function test_shouldNotSupportEIP1271() external {
		assertFalse(
			IERC165(address(safe)).supportsInterface(type(IERC1271).interfaceId)
		);

		(bool success, ) = address(safe).call(
			abi.encodeWithSignature("isValidSignature(bytes32,bytes)", keccak256("any interface"), "")
		);
		assertFalse(success);
	}

}

