// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/guard/OperatorsContext.sol";


abstract contract OperatorsContextTest is Test {

	bytes32 internal constant OPERATORS_SLOT = bytes32(uint256(1)); // `operators` mapping position

	OperatorsContext context;
	address guard = address(0x1111);
	address notGuard = address(0x1112);

	address safe = address(0xff);
	address alice = address(0xa11ce);
	address token = address(0x070ce2);


	function setUp() external {
		context = new OperatorsContext(guard);
	}


	function _mockStoredOperator(address _safe, address assetAddress, address operator) internal {
		vm.store(address(context), _operatorsSetSlotFor(_safe, assetAddress), bytes32(uint256(1)));
		vm.store(address(context), _operatorsFirstValueSlotFor(_safe, assetAddress), bytes32(uint256(uint160(operator))));
		vm.store(address(context), _operatorsIndexeSlotFor(_safe, assetAddress, operator), bytes32(uint256(1)));
	}


	function _operatorsSetSlotFor(address _safe, address assetAddress) internal pure returns (bytes32) {
		return keccak256(
			abi.encode(
				assetAddress, // Asset address as a mapping key
				keccak256(
					abi.encode(
						_safe, // Safe address as a mapping key
						OPERATORS_SLOT
					)
				)
			)
		);
	}

	function _operatorsFirstValueSlotFor(address _safe, address assetAddress) internal pure returns (bytes32) {
		// Hash array position to get position of a first item in the array
		return keccak256(
			abi.encode(
				_operatorsSetSlotFor(_safe, assetAddress) // `_values` array position
			)
		);
	}

	function _operatorsIndexeSlotFor(address _safe, address assetAddress, address operator) internal pure returns (bytes32) {
		return keccak256(
			abi.encode(
				operator, // Operator as a mapping key
				uint256(_operatorsSetSlotFor(_safe, assetAddress)) + 1 // `_indexes` mapping position
			)
		);
	}

}


/*----------------------------------------------------------*|
|*  # ADD                                                   *|
|*----------------------------------------------------------*/

contract OperatorsContext_Add_Test is OperatorsContextTest {

	function test_shouldFail_whenCallerIsNotGuard() external {
		vm.expectRevert("Sender is not guard address");
		vm.prank(notGuard);
		context.add(safe, token, alice);
	}

	function test_shouldAddOperatorToSafeUnderAsset() external {
		vm.prank(guard);
		context.add(safe, token, alice);

		// Operator has first index
		bytes32 operatorIndex = vm.load(address(context), _operatorsIndexeSlotFor(safe, token, alice));
		assertEq(uint256(operatorIndex), 1);
		// Operator is in a set
		bytes32 operatorValue = vm.load(address(context), _operatorsFirstValueSlotFor(safe, token)); // 1 - 1
		assertEq(uint256(operatorValue), uint256(uint160(alice)));
		// Set has one item
		bytes32 operatorsLength = vm.load(address(context), _operatorsSetSlotFor(safe, token));
		assertEq(uint256(operatorsLength), 1);
	}

	function test_shouldNotFail_whenOperatorIsStored() external {
		_mockStoredOperator(safe, token, alice);

		vm.prank(guard);
		context.add(safe, token, alice);

		// Set size does not change
		bytes32 operatorsLength = vm.load(address(context), _operatorsSetSlotFor(safe, token));
		assertEq(uint256(operatorsLength), 1);
	}

}


/*----------------------------------------------------------*|
|*  # REMOVE                                                *|
|*----------------------------------------------------------*/

contract OperatorsContext_Remove_Test is OperatorsContextTest {

	function test_shouldFail_whenCallerIsNotGuard() external {
		vm.expectRevert("Sender is not guard address");
		vm.prank(notGuard);
		context.remove(safe, token, alice);
	}

	function test_shouldRemoveOperatorFromSafeUnderAsset() external {
		_mockStoredOperator(safe, token, alice);

		vm.prank(guard);
		context.remove(safe, token, alice);

		// Operator has no index
		bytes32 operatorIndex = vm.load(address(context), _operatorsIndexeSlotFor(safe, token, alice));
		assertEq(uint256(operatorIndex), 0);
		// Set has no item
		bytes32 operatorsLength = vm.load(address(context), _operatorsSetSlotFor(safe, token));
		assertEq(uint256(operatorsLength), 0);
	}

	function test_shouldNotFail_whenOperatorIsNotStored() external {
		vm.prank(guard);
		context.remove(safe, token, alice);
	}

}


/*----------------------------------------------------------*|
|*  # HAS OPERATOR FOR                                      *|
|*----------------------------------------------------------*/

contract OperatorsContext_HasOperatorFor_Test is OperatorsContextTest {

	function test_shouldReturnTrue_whenSafeHasOperatorUnderAsset() external {
		_mockStoredOperator(safe, token, alice);

		bool hasOperator = context.hasOperatorFor(safe, token);

		assertEq(hasOperator, true);
	}

	function test_shouldReturnFalse_whenSafeDoesNotHaveOperatorUnderAsset() external {
		address otherToken = address(0x070ce3);
		_mockStoredOperator(safe, otherToken, alice);

		bool hasOperator = context.hasOperatorFor(safe, token);

		assertEq(hasOperator, false);
	}

}


/*----------------------------------------------------------*|
|*  # RESOLVE INVALID ALLOWANCE                             *|
|*----------------------------------------------------------*/

contract OperatorsContext_ResolveInvalidAllowance_Test is OperatorsContextTest {

	function test_shouldRemoveOperator_whenAllowanceIsZero() external {
		_mockStoredOperator(safe, token, alice);
		vm.mockCall(
			address(token),
			abi.encodeWithSignature("allowance(address,address)", safe, alice),
			abi.encode(0)
		);

		context.resolveInvalidAllowance(safe, token, alice);

		// Operator has no index
		bytes32 operatorIndex = vm.load(address(context), _operatorsIndexeSlotFor(safe, token, alice));
		assertEq(uint256(operatorIndex), 0);
		// Set has no item
		bytes32 operatorsLength = vm.load(address(context), _operatorsSetSlotFor(safe, token));
		assertEq(uint256(operatorsLength), 0);
	}

	function test_shouldNotRemoveOperator_whenAllowanceIsNotZero() external {
		_mockStoredOperator(safe, token, alice);
		vm.mockCall(
			address(token),
			abi.encodeWithSignature("allowance(address,address)", safe, alice),
			abi.encode(100e18)
		);

		context.resolveInvalidAllowance(safe, token, alice);

		// Operator has first index
		bytes32 operatorIndex = vm.load(address(context), _operatorsIndexeSlotFor(safe, token, alice));
		assertEq(uint256(operatorIndex), 1);
		// Operator is in a set
		bytes32 operatorValue = vm.load(address(context), _operatorsFirstValueSlotFor(safe, token)); // 1 - 1
		assertEq(uint256(operatorValue), uint256(uint160(alice)));
		// Set has one item
		bytes32 operatorsLength = vm.load(address(context), _operatorsSetSlotFor(safe, token));
		assertEq(uint256(operatorsLength), 1);
	}

}
