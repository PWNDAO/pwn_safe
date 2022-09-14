// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "forge-std/Test.sol";
import "../src/AssetTransferRights.sol";
import "../src/managers/RecipientPermissionManager.sol";


// The only reason for this contract is to expose internal functions of RecipientPermissionManager
// No additional logic is applied here
contract RecipientPermissionManagerExposed is AssetTransferRights {

	function checkValidPermission(
		address sender,
		MultiToken.Asset memory asset,
		RecipientPermission calldata permission,
		bytes calldata permissionSignature
	) external {
		_checkValidPermission(sender, asset, permission, permissionSignature);
	}

}


abstract contract RecipientPermissionManagerTest is Test {

	bytes32 internal constant GRANTED_PERMISSION_SLOT = bytes32(uint256(9)); // `grantedPermissions` mapping position
	bytes32 internal constant REVOKED_PERMISSION_SLOT = bytes32(uint256(10)); // `revokedPermissions` mapping position

	RecipientPermissionManagerExposed atr;
	address alice = address(0xa11ce);
	address bob = address(0xb0b);
	address token = address(0x070ce2);
	RecipientPermissionManager.RecipientPermission permission;
	bytes32 permissionHash;

	event RecipientPermissionGranted(bytes32 indexed permissionHash);
	event RecipientPermissionRevoked(bytes32 indexed permissionHash);

	constructor() {
		vm.etch(token, bytes("data"));
	}

	function setUp() virtual public {
		atr = new RecipientPermissionManagerExposed();

		permission = RecipientPermissionManager.RecipientPermission(
			MultiToken.Category.ERC721,
			address(0x1001),
			123,
			1,
			false,
			alice,
			bob,
			10302,
			false,
			keccak256("nonce")
		);
		permissionHash = atr.recipientPermissionHash(permission);
	}


	function _mockGrantedPermission(bytes32 _permissionHash) internal {
		bytes32 permissionSlot = keccak256(abi.encodePacked(_permissionHash, GRANTED_PERMISSION_SLOT));
		vm.store(address(atr), permissionSlot, bytes32(uint256(1)));
	}

	function _mockRevokedPermission(bytes32 _permissionHash) internal {
		bytes32 permissionSlot = keccak256(abi.encodePacked(_permissionHash, REVOKED_PERMISSION_SLOT));
		vm.store(address(atr), permissionSlot, bytes32(uint256(1)));
	}

}


/*----------------------------------------------------------*|
|*  # GRANT RECIPIENT PERMISSION                            *|
|*----------------------------------------------------------*/

contract RecipientPermissionManager_GrantRecipientPermission_Test is RecipientPermissionManagerTest {

	function test_shouldFail_whenCallerIsNotPermissionRecipient() external {
		vm.expectRevert("Sender is not permission recipient");
		vm.prank(bob);
		atr.grantRecipientPermission(permission);
	}

	function test_shouldFail_whenPermissionHasBeenGranted() external {
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Recipient permission is granted");
		vm.prank(alice);
		atr.grantRecipientPermission(permission);
	}

	function test_shouldFail_whenPermissionHasBeenRevoked() external {
		_mockRevokedPermission(permissionHash);

		vm.expectRevert("Recipient permission is revoked");
		vm.prank(alice);
		atr.grantRecipientPermission(permission);
	}

	function test_shouldStoreThatPermissionIsGranted() external {
		vm.prank(alice);
		atr.grantRecipientPermission(permission);

		bytes32 permissionSlot = keccak256(abi.encodePacked(permissionHash, GRANTED_PERMISSION_SLOT));
		bytes32 permissionGrantedValue = vm.load(address(atr), permissionSlot);
		assertEq(uint256(permissionGrantedValue), 1);
	}

	function test_shouldEmitRecipientPermissionGrantedEvent() external {
		vm.expectEmit(true, false, false, false);
		emit RecipientPermissionGranted(permissionHash);

		vm.prank(alice);
		atr.grantRecipientPermission(permission);
	}

}


/*----------------------------------------------------------*|
|*  # REVOKE RECIPIENT PERMISSION                           *|
|*----------------------------------------------------------*/

contract RecipientPermissionManager_RevokeRecipientPermission_Test is RecipientPermissionManagerTest {

	function test_shouldFail_whenCallerIsNotPermissionRecipient() external {
		vm.expectRevert("Sender is not permission recipient");
		vm.prank(bob);
		atr.revokeRecipientPermission(permission);
	}

	function test_shouldFail_whenPermissionHasBeenRevoked() external {
		_mockRevokedPermission(permissionHash);

		vm.expectRevert("Recipient permission is revoked");
		vm.prank(alice);
		atr.revokeRecipientPermission(permission);
	}

	function test_shouldStoreThatPermissionIsRevoked() external {
		vm.prank(alice);
		atr.revokeRecipientPermission(permission);

		bytes32 permissionSlot = keccak256(abi.encodePacked(permissionHash, REVOKED_PERMISSION_SLOT));
		bytes32 permissionRevokedValue = vm.load(address(atr), permissionSlot);
		assertEq(uint256(permissionRevokedValue), 1);
	}

	function test_shouldEmitRecipientPermissionRevokedEvent() external {
		vm.expectEmit(true, false, false, false);
		emit RecipientPermissionRevoked(permissionHash);

		vm.prank(alice);
		atr.revokeRecipientPermission(permission);
	}

}


/*----------------------------------------------------------*|
|*  # RECIPIENT PERMISSION HASH                             *|
|*----------------------------------------------------------*/

contract RecipientPermissionManager_RecipientPermissionHash_Test is RecipientPermissionManagerTest {

	function test_shouldReturnPermissionHash() external {
		permission = RecipientPermissionManager.RecipientPermission(
			MultiToken.Category.ERC721,
			address(0x1234),
			1234,
			103321,
			false,
			alice,
			bob,
			10302,
			true,
			keccak256("lightning round!!")
		);
		permissionHash = atr.recipientPermissionHash(permission);

		bytes32 expectedHash = keccak256(abi.encodePacked(
			"\x19\x01",
			keccak256(abi.encode(
				keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
				keccak256(bytes("AssetTransferRights")),
				keccak256(bytes("0.1")),
				block.chainid,
				address(atr)
			)),
			keccak256(abi.encode(
				keccak256("RecipientPermission(uint8 assetCategory,address assetAddress,uint256 assetId,uint256 assetAmount,bool ignoreAssetIdAndAmount,address recipient,address agent,uint40 expiration,bool isPersistent,bytes32 nonce)"),
				permission.assetCategory,
				permission.assetAddress,
				permission.assetId,
				permission.assetAmount,
				permission.ignoreAssetIdAndAmount,
				permission.recipient,
				permission.expiration,
				permission.isPersistent,
				permission.nonce
			))
		));

		assertEq(permissionHash, expectedHash);
	}

}


/*----------------------------------------------------------*|
|*  # CHECK VALID PERMISSION                                *|
|*----------------------------------------------------------*/

contract RecipientPermissionManager_CheckValidPermission_Test is RecipientPermissionManagerTest {

	function setUp() override public {
		super.setUp();

		vm.warp(10202);
	}

	function test_shouldFail_whenPermissionIsExpired() external {
		permission.expiration = uint40(block.timestamp) - 100;
		permissionHash = atr.recipientPermissionHash(permission);
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Recipient permission is expired");
		atr.checkValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);
	}

	function test_shouldPass_whenPermissionHasNoExpiration() external {
		permission.expiration = 0;
		permissionHash = atr.recipientPermissionHash(permission);
		_mockGrantedPermission(permissionHash);

		atr.checkValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);
	}

	function test_shouldFail_whenCallerIsNotPermittedAgent() external {
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Caller is not permitted agent");
		atr.checkValidPermission(
			alice,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);
	}

	function test_shouldPass_whenPermittedAgentIsNotStated() external {
		permission.agent = address(0);
		permissionHash = atr.recipientPermissionHash(permission);
		_mockGrantedPermission(permissionHash);

		atr.checkValidPermission(
			alice,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);
	}

	function test_shouldFail_whenAssetIsNotPermitted() external {
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Invalid permitted asset");
		atr.checkValidPermission(
			bob,
			MultiToken.Asset(MultiToken.Category.ERC1155, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);

		vm.expectRevert("Invalid permitted asset");
		atr.checkValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, address(0x1221), permission.assetId, permission.assetAmount),
			permission,
			""
		);

		vm.expectRevert("Invalid permitted asset");
		atr.checkValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, 42, permission.assetAmount),
			permission,
			""
		);

		vm.expectRevert("Invalid permitted asset");
		atr.checkValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, 2),
			permission,
			""
		);
	}

	function test_shouldIgnoreAssetIdAndAmount_whenFlagIsTrue() external {
		permission.ignoreAssetIdAndAmount = true;
		permission.isPersistent = true;
		permissionHash = atr.recipientPermissionHash(permission);
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Invalid permitted asset");
		atr.checkValidPermission(
			bob,
			MultiToken.Asset(MultiToken.Category.ERC1155, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);

		vm.expectRevert("Invalid permitted asset");
		atr.checkValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, address(0x1221), permission.assetId, permission.assetAmount),
			permission,
			""
		);

		atr.checkValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, 42, permission.assetAmount),
			permission,
			""
		);

		atr.checkValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, 2),
			permission,
			""
		);
	}

	function test_shouldFail_whenPermissionHasBeenRevoked() external {
		_mockRevokedPermission(permissionHash);
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Recipient permission is revoked");
		atr.checkValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);
	}

	function test_shouldFail_whenPermissionHasNotBeenGranted_whenERC1271InvalidSignature() external {
		vm.etch(alice, bytes("data"));
		vm.mockCall(
			alice,
			abi.encodeWithSignature("isValidSignature(bytes32,bytes)"),
			abi.encode(bytes4(0xffffffff))
		);

		vm.expectRevert("Signature on behalf of contract is invalid");
		atr.checkValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);
	}

	function test_shouldFail_whenPermissionHasNotBeenGranted_whenInvalidSignature() external {
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(6, keccak256("invalid data"));

		vm.expectRevert("Permission signer is not stated as recipient");
		atr.checkValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			abi.encodePacked(r, s, v)
		);
	}

	function test_shouldPass_whenPermissionHasBeenGranted() external {
		_mockGrantedPermission(permissionHash);

		atr.checkValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);
	}

	function test_shouldPass_whenERC1271ValidSignature() external {
		vm.etch(alice, bytes("data"));
		vm.mockCall(
			alice,
			abi.encodeWithSignature("isValidSignature(bytes32,bytes)"),
			abi.encode(bytes4(0x1626ba7e))
		);

		atr.checkValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);
	}

	function test_shouldPass_whenValidSignature() external {
		uint256 pk = 6;
		address recipient = vm.addr(pk);
		permission.recipient = recipient;
		permissionHash = atr.recipientPermissionHash(permission);
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, permissionHash);

		atr.checkValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			abi.encodePacked(r, s, v)
		);
	}

	function test_shouldNotStoreThatPermissionIsRevoked_whenPersistent() external {
		permission.isPersistent = true;
		permissionHash = atr.recipientPermissionHash(permission);
		_mockGrantedPermission(permissionHash);

		atr.checkValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);

		bytes32 permissionSlot = keccak256(abi.encodePacked(permissionHash, REVOKED_PERMISSION_SLOT));
		bytes32 permissionRevokedValue = vm.load(address(atr), permissionSlot);
		assertEq(uint256(permissionRevokedValue), 0);
	}

	function test_shouldStoreThatPermissionIsRevoked_whenNotPersistent() external {
		_mockGrantedPermission(permissionHash);

		atr.checkValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);

		bytes32 permissionSlot = keccak256(abi.encodePacked(permissionHash, REVOKED_PERMISSION_SLOT));
		bytes32 permissionRevokedValue = vm.load(address(atr), permissionSlot);
		assertEq(uint256(permissionRevokedValue), 1);
	}

	function test_shouldEmitRecipientPermissionRevokedEvent() external {
		_mockGrantedPermission(permissionHash);

		vm.expectEmit(true, false, false, false);
		emit RecipientPermissionRevoked(permissionHash);

		atr.checkValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);
	}

}
