// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/AssetTransferRights.sol";


abstract contract PWNSafeValidatorManagerTest is Test {

	bytes32 constant VALIDATOR_SLOT = bytes32(uint256(3)); // `safeValidator` property position

	AssetTransferRights atr;
	address notOwner = address(0xff);
	address validator = address(0xabcdef);

	constructor() {

	}

	function setUp() external {
		atr = new AssetTransferRights();
	}

}

/*----------------------------------------------------------*|
|*  # SET PWNSAFE VALIDATOR                                 *|
|*----------------------------------------------------------*/

contract PWNSafeValidatorManager_SetPWNSafeValidator_Test is PWNSafeValidatorManagerTest {

	function test_shouldFail_whenCallerIsNotOwner() external {
		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(notOwner);
		atr.setPWNSafeValidator(validator);
	}

	function test_shouldSetPWNSafeValidator() external {
		vm.store(address(atr), VALIDATOR_SLOT, bytes32(0));

		atr.setPWNSafeValidator(validator);

		assertEq(
			vm.load(address(atr), VALIDATOR_SLOT),
			bytes32(uint256(uint160(validator)))
		);
	}

}
