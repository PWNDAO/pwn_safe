// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "forge-std/Test.sol";

import "@pwn-safe/module/AssetTransferRights.sol";
import "@pwn-safe/module/RecipientPermissionManager.sol";


// The only reason for this contract is to expose internal functions of RecipientPermissionManager
// No additional logic is applied here
contract RecipientPermissionManagerExposed is AssetTransferRights {

	constructor(address whitelist) AssetTransferRights(whitelist) {}

	function useValidPermission(
		address sender,
		MultiToken.Asset memory asset,
		RecipientPermission calldata permission,
		bytes calldata permissionSignature
	) external {
		_useValidPermission(sender, asset, permission, permissionSignature);
	}

}


abstract contract RecipientPermissionManagerTest is Test {

	bytes32 internal constant GRANTED_PERMISSION_SLOT = bytes32(uint256(6)); // `grantedPermissions` mapping position
	bytes32 internal constant REVOKED_PERMISSION_NONCE_SLOT = bytes32(uint256(7)); // `revokedPermissionNonces` mapping position

	RecipientPermissionManagerExposed atr;
	address alice = address(0xa11ce);
	address bob = address(0xb0b);
	address token = address(0x070ce2);
	RecipientPermissionManager.RecipientPermission permission;
	bytes32 permissionHash;
	address whitelist = makeAddr("whitelist");

	event RecipientPermissionGranted(bytes32 indexed permissionHash);
	event RecipientPermissionNonceRevoked(address indexed recipient, bytes32 indexed permissionNonce);

	constructor() {
		vm.etch(token, bytes("data"));
	}

	function setUp() virtual public {
		atr = new RecipientPermissionManagerExposed(whitelist);

		permission = RecipientPermissionManager.RecipientPermission(
			MultiToken.Category.ERC721, // assetCategory
			address(0x1001), // assetAddress
			123, // assetId
			1, // assetAmount
			false, // ignoreAssetIdAndAmount
			alice, // recipient
			bob, // agent
			10302, // expiration
			false, // isPersistent
			keccak256("nonce") // nonce
		);
		permissionHash = atr.recipientPermissionHash(permission);
	}


	function _mockGrantedPermission(bytes32 _permissionHash) internal {
		bytes32 permissionSlot = keccak256(abi.encode(_permissionHash, GRANTED_PERMISSION_SLOT));
		vm.store(address(atr), permissionSlot, bytes32(uint256(1)));
	}

	function _valueOfGrantedPermission(bytes32 _permissionHash) internal view returns (bytes32) {
		bytes32 permissionSlot = keccak256(abi.encode(_permissionHash, GRANTED_PERMISSION_SLOT));
		return vm.load(address(atr), permissionSlot);
	}

	function _mockRevokedPermissionNonce(address _owner, bytes32 _permissionNonce) internal {
		bytes32 ownersPermissionNonceSlot = keccak256(abi.encode(_owner, REVOKED_PERMISSION_NONCE_SLOT));
		bytes32 permissionNonceSlot = keccak256(abi.encode(_permissionNonce, ownersPermissionNonceSlot));
		vm.store(address(atr), permissionNonceSlot, bytes32(uint256(1)));
	}

	function _valueOfRevokePermissionNonce(address _owner, bytes32 _permissionNonce) internal view returns (bytes32) {
		bytes32 ownersPermissionNonceSlot = keccak256(abi.encode(_owner, REVOKED_PERMISSION_NONCE_SLOT));
		bytes32 permissionNonceSlot = keccak256(abi.encode(_permissionNonce, ownersPermissionNonceSlot));
		return vm.load(address(atr), permissionNonceSlot);
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
		_mockRevokedPermissionNonce(permission.recipient, permission.nonce);

		vm.expectRevert("Recipient permission nonce is revoked");
		vm.prank(alice);
		atr.grantRecipientPermission(permission);
	}

	function test_shouldStoreThatPermissionIsGranted() external {
		vm.prank(alice);
		atr.grantRecipientPermission(permission);

		bytes32 permissionGrantedValue = _valueOfGrantedPermission(permissionHash);
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

	bytes32 nonce = keccak256("alice nonce");

	function test_shouldFail_whenPermissionHasBeenRevoked() external {
		_mockRevokedPermissionNonce(alice, nonce);

		vm.expectRevert("Recipient permission nonce is revoked");
		vm.prank(alice);
		atr.revokeRecipientPermission(nonce);
	}

	function test_shouldStoreThatPermissionIsRevoked() external {
		vm.prank(alice);
		atr.revokeRecipientPermission(nonce);

		bytes32 permissionNonceRevokedValue = _valueOfRevokePermissionNonce(alice, nonce);
		assertEq(uint256(permissionNonceRevokedValue), 1);
	}

	function test_shouldEmitRecipientPermissionNonceRevokedEvent() external {
		vm.expectEmit(true, true, false, false);
		emit RecipientPermissionNonceRevoked(alice, nonce);

		vm.prank(alice);
		atr.revokeRecipientPermission(nonce);
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
|*  # USE VALID PERMISSION                                  *|
|*----------------------------------------------------------*/

contract RecipientPermissionManager_UseValidPermission_Test is RecipientPermissionManagerTest {

	function setUp() override public {
		super.setUp();

		vm.warp(10202);
	}

	function test_shouldFail_whenPermissionIsExpired() external {
		permission.expiration = uint40(block.timestamp) - 100;
		permissionHash = atr.recipientPermissionHash(permission);
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Recipient permission is expired");
		atr.useValidPermission(
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

		atr.useValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);
	}

	function test_shouldFail_whenCallerIsNotPermittedAgent() external {
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Caller is not permitted agent");
		atr.useValidPermission(
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

		atr.useValidPermission(
			alice,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);
	}

	function test_shouldFail_whenAssetIsNotPermitted() external {
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Invalid permitted asset");
		atr.useValidPermission(
			bob,
			MultiToken.Asset(MultiToken.Category.ERC1155, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);

		vm.expectRevert("Invalid permitted asset");
		atr.useValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, address(0x1221), permission.assetId, permission.assetAmount),
			permission,
			""
		);

		vm.expectRevert("Invalid permitted asset");
		atr.useValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, 42, permission.assetAmount),
			permission,
			""
		);

		vm.expectRevert("Invalid permitted asset");
		atr.useValidPermission(
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
		atr.useValidPermission(
			bob,
			MultiToken.Asset(MultiToken.Category.ERC1155, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);

		vm.expectRevert("Invalid permitted asset");
		atr.useValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, address(0x1221), permission.assetId, permission.assetAmount),
			permission,
			""
		);

		atr.useValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, 42, permission.assetAmount),
			permission,
			""
		);

		atr.useValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, 2),
			permission,
			""
		);
	}

	function test_shouldFail_whenPermissionHasBeenRevoked() external {
		_mockRevokedPermissionNonce(permission.recipient, permission.nonce);
		_mockGrantedPermission(permissionHash);

		vm.expectRevert("Recipient permission nonce is revoked");
		atr.useValidPermission(
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
		atr.useValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);
	}

	function test_shouldFail_whenPermissionHasNotBeenGranted_whenInvalidSignature() external {
		(uint8 v, bytes32 r, bytes32 s) = vm.sign(6, keccak256("invalid data"));

		vm.expectRevert("Permission signer is not stated as recipient");
		atr.useValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			abi.encodePacked(r, s, v)
		);
	}

	function test_shouldPass_whenPermissionHasBeenGranted() external {
		_mockGrantedPermission(permissionHash);

		atr.useValidPermission(
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

		atr.useValidPermission(
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

		atr.useValidPermission(
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

		atr.useValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);

		bytes32 permissionNonceRevokedValue = _valueOfRevokePermissionNonce(permission.recipient, permission.nonce);
		assertEq(uint256(permissionNonceRevokedValue), 0);
	}

	function test_shouldStoreThatPermissionIsRevoked_whenNotPersistent() external {
		_mockGrantedPermission(permissionHash);

		atr.useValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);

		bytes32 permissionNonceRevokedValue = _valueOfRevokePermissionNonce(permission.recipient, permission.nonce);
		assertEq(uint256(permissionNonceRevokedValue), 1);
	}

	function testFail_shouldNotEmitRecipientPermissionNonceRevokedEvent_whenPersistent() external {
		permission.isPersistent = true;
		permissionHash = atr.recipientPermissionHash(permission);
		_mockGrantedPermission(permissionHash);

		vm.expectEmit(true, true, false, false);
		emit RecipientPermissionNonceRevoked(permission.recipient, permission.nonce);

		atr.useValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);
	}

	function test_shouldEmitRecipientPermissionNonceRevokedEvent_whenNotPersistent() external {
		_mockGrantedPermission(permissionHash);

		vm.expectEmit(true, true, false, false);
		emit RecipientPermissionNonceRevoked(permission.recipient, permission.nonce);

		atr.useValidPermission(
			bob,
			MultiToken.Asset(permission.assetCategory, permission.assetAddress, permission.assetId, permission.assetAmount),
			permission,
			""
		);
	}

}
