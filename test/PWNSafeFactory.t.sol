// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/factory/PWNSafeFactory.sol";


abstract contract PWNSafeFactoryTest is Test {

	bytes32 internal constant GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;
	address internal constant SENTINEL_MODULES = address(0x1);

	PWNSafeFactory factory;
	address gsSingleton = address(0x01);
	address gsProxyFactory = address(0x02);
	address fallbackHandler = address(0x03);
	address module = address(0x04);
	address guard = address(0x05);

	address safe = address(0x2afe);
	uint256 threshold = 2;

	constructor() {
		vm.etch(gsProxyFactory, bytes("data"));
		vm.etch(safe, bytes("data"));
	}

	function setUp() external {
		factory = new PWNSafeFactory(
			gsSingleton,
			gsProxyFactory,
			fallbackHandler,
			module,
			guard
		);

		vm.mockCall(
			gsProxyFactory,
			abi.encodeWithSignature("createProxy(address,bytes)", gsSingleton, ""),
			abi.encode(safe)
		);
	}


	function _owners() internal pure returns (address[] memory owners) {
		owners = new address[](3);
		owners[0] = address(0x1000);
		owners[1] = address(0x1001);
		owners[2] = address(0x1002);
	}

}


/*----------------------------------------------------------*|
|*  # DEPLOY PROXY                                          *|
|*----------------------------------------------------------*/

contract PWNSafeFactory_DeployProxy_Test is PWNSafeFactoryTest {

	function test_shouldCreateNewGnosisSafeProxy() external {
		vm.expectCall(
			gsProxyFactory,
			abi.encodeWithSignature("createProxy(address,bytes)", gsSingleton, "")
		);
		factory.deployProxy(_owners(), threshold);
	}

	function test_shouldCallSetupOnSafe() external {
		vm.expectCall(
			safe,
			abi.encodeWithSignature(
				"setup(address[],uint256,address,bytes,address,address,uint256,address)",
				_owners(),
				threshold,
				address(factory),
				abi.encodeWithSelector(PWNSafeFactory.setupNewSafe.selector),
				fallbackHandler,
				address(0),
				0,
				payable(address(0))
			)
		);
		factory.deployProxy(_owners(), threshold);
	}

	function test_shouldMarkSafeAsValid() external {
		factory.deployProxy(_owners(), threshold);

		bytes32 isValid = vm.load(address(factory), keccak256(abi.encode(safe, uint256(0))));
		assertEq(uint256(isValid), 1);
	}

}


/*----------------------------------------------------------*|
|*  # SETUP NEW SAFE                                        *|
|*----------------------------------------------------------*/

contract PWNSafeFactory_SetupNewSafe_Test is PWNSafeFactoryTest {

	function test_shouldFail_whenCalledDirectly() external {

	}

	function test_shouldFail_whenCallerIsNotGnosisSafeProxy() external {

	}

	function test_shouldFail_whenProxyHasWrongSigleton() external {

	}

	function test_shouldEnableATRModule() external {

	}

	function test_shouldSetATRGuard() external {

	}

}
