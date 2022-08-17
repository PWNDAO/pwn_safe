// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/AssetTransferRights.sol";


abstract contract AssetTransferRightsGuardManagerTest is Test {

	bytes32 constant GUARD_SLOT = bytes32(uint256(2)); // `atrGuard` property position

	AssetTransferRights atr;
	address notOwner = address(0xff);
	address guard = address(0xabcdef);

	constructor() {

	}

	function setUp() external {
		atr = new AssetTransferRights();
	}

}

/*----------------------------------------------------------*|
|*  # SET ASSET TRANSFER RIGHTS GUARD                       *|
|*----------------------------------------------------------*/

contract AssetTransferRightsGuardManager_SetAssetTransferRightsGuard_Test is AssetTransferRightsGuardManagerTest {

	function test_shouldFail_whenCallerIsNotOwner() external {
		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(notOwner);
		atr.setAssetTransferRightsGuard(guard);
	}

	function test_shouldSetGuard() external {
		vm.store(address(atr), GUARD_SLOT, bytes32(0));

		atr.setAssetTransferRightsGuard(guard);

		assertEq(
			vm.load(address(atr), GUARD_SLOT),
			bytes32(uint256(uint160(guard)))
		);
	}

}
