// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/guard/AssetTransferRightsGuard.sol";


abstract contract AssetTransferRightsGuardTest is Test {

	address internal constant erc1820Registry = address(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

	AssetTransferRightsGuard guard;
	address module = address(0x7701);
	address operators = address(0x7702);
	address safe = address(0x2afe);
	address token = address(0x070ce2);
	address alice = address(0xa11ce);

	constructor() {
		// ERC1820 Registry
		vm.etch(erc1820Registry, bytes("data"));
		vm.mockCall(
			erc1820Registry,
			abi.encodeWithSignature("getInterfaceImplementer(address,bytes32)"),
			abi.encode(address(0))
		);
		vm.etch(module, bytes("data"));
		vm.etch(operators, bytes("data"));
	}

	function setUp() external {
		guard = new AssetTransferRightsGuard();
		guard.initialize(module, operators);
	}

}


/*----------------------------------------------------------*|
|*  # INITIALIZE                                            *|
|*----------------------------------------------------------*/

contract AssetTransferRightsGuard_Initialize_Test is AssetTransferRightsGuardTest {

}


/*----------------------------------------------------------*|
|*  # CHECK TRANSACTION                                     *|
|*----------------------------------------------------------*/

contract AssetTransferRightsGuard_CheckTransaction_Test is AssetTransferRightsGuardTest {

}


/*----------------------------------------------------------*|
|*  # CHECK AFTER EXECUTION                                 *|
|*----------------------------------------------------------*/

contract AssetTransferRightsGuard_CheckAfterExecution_Test is AssetTransferRightsGuardTest {

}


/*----------------------------------------------------------*|
|*  # HAS OPERATOR FOR                                      *|
|*----------------------------------------------------------*/

contract AssetTransferRightsGuard_HasOperatorFor_Test is AssetTransferRightsGuardTest {

	function test_shouldReturnTrue_whenCollectionHasOperator() external {
		vm.mockCall(
			operators,
			abi.encodeWithSignature("hasOperatorFor(address,address)", safe, token),
			abi.encode(true)
		);

		bool hasOperator = guard.hasOperatorFor(safe, token);

		assertEq(hasOperator, true);
	}

	function test_shouldReturnTrue_whenERC777HasDefaultOperator() external {
		vm.mockCall(
			erc1820Registry,
			abi.encodeWithSignature("getInterfaceImplementer(address,bytes32)"),
			abi.encode(token)
		);

		address[] memory defaultOperators = new address[](1);
		defaultOperators[0] = alice;
		vm.mockCall(
			token,
			abi.encodeWithSignature("defaultOperators()"),
			abi.encode(defaultOperators)
		);
		vm.mockCall(
			token,
			abi.encodeWithSignature("isOperatorFor(address,address)", alice, safe),
			abi.encode(true)
		);

		bool hasOperator = guard.hasOperatorFor(safe, token);

		assertEq(hasOperator, true);
	}

	function test_shouldReturnFalse_whenCollectionHasNoOperator() external {
		vm.mockCall(
			operators,
			abi.encodeWithSignature("hasOperatorFor(address,address)", safe, token),
			abi.encode(false)
		);

		bool hasOperator = guard.hasOperatorFor(safe, token);

		assertEq(hasOperator, false);
	}

}
