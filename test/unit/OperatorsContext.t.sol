// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "forge-std/Test.sol";

import "@pwn-safe/guard/OperatorsContext.sol";


// The only reason for this contract is to expose internal functions of OperatorsContext
// No additional logic is applied here
contract OperatorsContextExposed is OperatorsContext {

    function addOperator(address safe, address asset, address operator) external {
        _addOperator(safe, asset, operator);
    }

    function removeOperator(address safe, address asset, address operator) external {
        _removeOperator(safe, asset, operator);
    }

}

abstract contract OperatorsContextTest is Test {

    bytes32 internal constant OPERATORS_SLOT = bytes32(uint256(0)); // `operators` mapping position

    OperatorsContextExposed context;
    address safe = makeAddr("safe");
    address alice = makeAddr("alice");
    address token = makeAddr("token");


    function setUp() external {
        context = new OperatorsContextExposed();
    }


    function _mockStoredOperator(address _safe, address assetAddress, address operator) internal {
        _mockStoredOperator(_safe, assetAddress, operator, 0);
    }

    // Used index has to be incremental. Skipping an index leads to undefined behaviour.
    function _mockStoredOperator(address _safe, address assetAddress, address operator, uint256 index) internal {
        // Store new number of operators
        vm.store(
            address(context),
            _operatorsSetSlotFor(_safe, assetAddress),
            bytes32(index + 1)
        );
        // Store operator
        vm.store(
            address(context),
            bytes32(uint256(_operatorsFirstValueSlotFor(_safe, assetAddress)) + index),
            bytes32(uint256(uint160(operator)))
        );
        // Store index of the operator
        vm.store(
            address(context),
            _operatorsIndexeSlotFor(_safe, assetAddress, operator),
            bytes32(index + 1)
        );
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

    function test_shouldAddOperatorToSafeUnderAsset() external {
        context.addOperator(safe, token, alice);

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

        context.addOperator(safe, token, alice);

        // Set size does not change
        bytes32 operatorsLength = vm.load(address(context), _operatorsSetSlotFor(safe, token));
        assertEq(uint256(operatorsLength), 1);
    }

}


/*----------------------------------------------------------*|
|*  # REMOVE                                                *|
|*----------------------------------------------------------*/

contract OperatorsContext_Remove_Test is OperatorsContextTest {

    function test_shouldRemoveOperatorFromSafeUnderAsset() external {
        _mockStoredOperator(safe, token, alice);

        context.removeOperator(safe, token, alice);

        // Operator has no index
        bytes32 operatorIndex = vm.load(address(context), _operatorsIndexeSlotFor(safe, token, alice));
        assertEq(uint256(operatorIndex), 0);
        // Set has no item
        bytes32 operatorsLength = vm.load(address(context), _operatorsSetSlotFor(safe, token));
        assertEq(uint256(operatorsLength), 0);
    }

    function test_shouldNotFail_whenOperatorIsNotStored() external {
        context.removeOperator(safe, token, alice);
    }

}


/*----------------------------------------------------------*|
|*  # HAS OPERATOR FOR                                      *|
|*----------------------------------------------------------*/

contract OperatorsContext_HasOperatorFor_Test is OperatorsContextTest {

    function test_shouldReturnTrue_whenSafeHasOperatorUnderAsset() external {
        _mockStoredOperator(safe, token, alice);

        bool hasOperator = context.hasOperatorFor(safe, token);

        assertTrue(hasOperator);
    }

    function test_shouldReturnFalse_whenSafeDoesNotHaveOperatorUnderAsset() external {
        address otherToken = makeAddr("other token");
        _mockStoredOperator(safe, otherToken, alice);

        bool hasOperator = context.hasOperatorFor(safe, token);

        assertFalse(hasOperator);
    }

}


/*----------------------------------------------------------*|
|*  # OPERATORS FOR                                         *|
|*----------------------------------------------------------*/

contract OperatorsContext_OperatorsFor_Test is OperatorsContextTest {

    function test_shouldReturnEmptyList_whenNoRecordedOperators() external {
        address[] memory operators = context.operatorsFor(safe, token);

        assertEq(operators.length, 0);
    }

    function test_shouldReturnListOfAllOperators_whenSomeRecordedOperators() external {
        address bob = makeAddr("bob");
        address peter = makeAddr("peter");
        _mockStoredOperator(safe, token, alice, 0);
        _mockStoredOperator(safe, token, bob, 1);
        _mockStoredOperator(safe, token, peter, 2);

        address[] memory operators = context.operatorsFor(safe, token);

        assertEq(operators.length, 3);
        assertEq(operators[0], alice);
        assertEq(operators[1], bob);
        assertEq(operators[2], peter);
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
