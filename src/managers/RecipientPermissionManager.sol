// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";

import "MultiToken/MultiToken.sol";


abstract contract RecipientPermissionManager {

	/*----------------------------------------------------------*|
	|*  # VARIABLES & CONSTANTS DEFINITIONS                     *|
	|*----------------------------------------------------------*/

	bytes4 constant internal EIP1271_VALID_SIGNATURE = 0x1626ba7e;

	bytes32 constant internal RECIPIENT_PERMISSION_TYPEHASH = keccak256(
		"RecipientPermission(uint8 category,address assetAddress,uint256 id,uint256 amount,address recipient,address agent,uint40 expiration,bytes32 nonce)"
	);

	struct RecipientPermission {
		// MultiToken.Asset
		MultiToken.Category assetCategory;
		address assetAddress;
		uint256 assetId;
		uint256 assetAmount;
		// Permission signer
		address recipient;
		// Optional address of ATR token holder that will initiate a transfer
		address agent;
		// Optional (highly recommended) expiration timestamp in seconds. 0 = no expiration.
		uint40 expiration;
		bytes32 nonce;
	}

	/**
	 * Mapping of recipient permissions granted on-chain by recipient permission struct typed hash.
	 */
	mapping (bytes32 => bool) public grantedPermissions;

	/**
	 * Mapping of revoked recipient permissions by recipient permission struct typed hash.
	 */
	mapping (bytes32 => bool) public revokedPermissions;


	/*----------------------------------------------------------*|
	|*  # EVENTS & ERRORS DEFINITIONS                           *|
	|*----------------------------------------------------------*/

	event RecipientPermissionGranted(bytes32 indexed permissionHash); // More data for dune analytics?
	event RecipientPermissionRevoked(bytes32 indexed permissionHash);



	function grantRecipientPermission(RecipientPermission calldata permission) external {
		// Check that caller is permission signer
		require(msg.sender == permission.recipient, "Sender is not permission recipient");

		bytes32 permissionHash = recipientPermissionHash(permission);

		// Check that permission is not have been granted
		require(grantedPermissions[permissionHash] == false, "Recipient permission is granted");

		// Check that permission is not have been revoked
		require(revokedPermissions[permissionHash] == false, "Recipient permission is revoked");

		// Grant permission
		grantedPermissions[permissionHash] = true;

		// Emit event
		emit RecipientPermissionGranted(permissionHash);
	}

	function revokeRecipientPermission(RecipientPermission calldata permission) external {
		// Check that caller is permission signer
		require(msg.sender == permission.recipient, "Sender is not permission recipient");

		bytes32 permissionHash = recipientPermissionHash(permission);

		// Check that permission is not have been revoked
		require(revokedPermissions[permissionHash] == false, "Recipient permission is revoked");

		// Revoke permission
		revokedPermissions[permissionHash] = true;

		// Emit event
		emit RecipientPermissionRevoked(permissionHash);
	}



	function recipientPermissionHash(RecipientPermission calldata permission) public view returns (bytes32) {
		return keccak256(abi.encodePacked(
			"\x19\x01",
			// Domain separator is composing to prevent replay attack in case of an Ethereum fork
			keccak256(abi.encode(
				keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
				keccak256(bytes("AssetTransferRights")),
				keccak256(bytes("0.1")),
				block.chainid,
				address(this)
			)),
			keccak256(abi.encode(
				RECIPIENT_PERMISSION_TYPEHASH,
				permission.assetCategory,
				permission.assetAddress,
				permission.assetId,
				permission.assetAmount,
				permission.recipient,
				permission.expiration,
				permission.nonce
			))
		));
	}



	function _checkValidPermission(
		address sender,
		MultiToken.Asset memory asset,
		RecipientPermission calldata permission,
		bytes calldata permissionSignature
	) internal {
		// Check that permission is not expired
		require(permission.expiration == 0 || block.timestamp < permission.expiration, "Recipient permission is expired");

		// Check permitted agent
		require(permission.agent == address(0) || sender == permission.agent, "Caller is not permitted agent");

		// Check correct asset
		require(permission.assetCategory == asset.category, "Invalid permitted asset");
		require(permission.assetAddress == asset.assetAddress, "Invalid permitted asset");
		require(permission.assetId == asset.id, "Invalid permitted asset");
		require(permission.assetAmount == asset.amount, "Invalid permitted asset");

		// Compute EIP-712 structured data hash
		bytes32 permissionHash = recipientPermissionHash(permission);

		// Check that permission is not revoked
		require(revokedPermissions[permissionHash] == false, "Recipient permission is revoked");

		// Check that permission is granted
		// Via on-chain tx, EIP-1271 or off-chain signature
		if (grantedPermissions[permissionHash] == true) {
			// Permission is granted on-chain, no need to check signature
		} else if (permission.recipient.code.length > 0) {
			// Check that permission is valid
			require(IERC1271(permission.recipient).isValidSignature(permissionHash, permissionSignature) == EIP1271_VALID_SIGNATURE, "Signature on behalf of contract is invalid");
		} else {
			// Check that permission signature is valid
			require(ECDSA.recover(permissionHash, permissionSignature) == permission.recipient, "Permission signer is not stated as recipient");
		}

		// Mark used permission as revoked
		revokedPermissions[permissionHash] = true;

		// Emit event
		emit RecipientPermissionRevoked(permissionHash);
	}

}
