// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/AssetTransferRights.sol";


abstract contract WhitelistManagerTest is Test {

	bytes32 constant USE_WHITELIST_SLOT = bytes32(uint256(0)); // `useWhitelist` flag position (combined with `owner`)
	bytes32 constant IS_WHITELISTED_SLOT = bytes32(uint256(1)); // `isWhitelisted` mapping position

	AssetTransferRights atr;
	address notOwner = address(0xff);
	address asset = address(0x01);

	constructor() {

	}

	function setUp() external {
		atr = new AssetTransferRights();
	}

}

/*----------------------------------------------------------*|
|*  # SET USE WHITELIST                                     *|
|*----------------------------------------------------------*/

contract WhitelistManager_SetUseWhitelist_Test is WhitelistManagerTest {

	function test_shouldFail_whenCallerIsNotOwner() external {
		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(notOwner);
		atr.setUseWhitelist(true);
	}

	function test_shouldSetIfWhitelistIsUsed() external {
		// don't need to set useWhitelist value as it is by default 0
		bytes32 zeroSlotValue = bytes32(bytes20(address(this))) >> 96;
		vm.store(address(atr), USE_WHITELIST_SLOT, zeroSlotValue);

		atr.setUseWhitelist(true);

		// value is combined with owner address -> value is at 161th bit from right
		assertEq(
			uint256(vm.load(address(atr), USE_WHITELIST_SLOT) >> 160) & 1,
			1
		);
	}

}


/*----------------------------------------------------------*|
|*  # SET IS WHITELISTED                                    *|
|*----------------------------------------------------------*/

contract WhitelistManager_SetIsWhitelisted_Test is WhitelistManagerTest {

	function test_shouldFail_whenCallerIsNotOwner() external {
		vm.expectRevert("Ownable: caller is not the owner");
		vm.prank(notOwner);
		atr.setIsWhitelisted(asset, true);
	}

	function test_shouldSetIfAddressIsWhitelisted() external {
		bytes32 assetSlot = keccak256(abi.encode(asset, IS_WHITELISTED_SLOT));
		vm.store(address(atr), assetSlot, bytes32(uint256(0)));

		atr.setIsWhitelisted(asset, true);

		assertEq(
			uint256(vm.load(address(atr), assetSlot)),
			1
		);
	}

}
