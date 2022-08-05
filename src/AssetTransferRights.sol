// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/utils/introspection/ERC165Checker.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";

import "safe-contracts/base/ModuleManager.sol";
import "safe-contracts/common/Enum.sol";
import "safe-contracts/common/StorageAccessible.sol";
import "safe-contracts/proxies/GnosisSafeProxy.sol";

import "MultiToken/MultiToken.sol";

import "./IAssetTransferRightsGuard.sol";
import "./WhitelistManager.sol";
import "./TokenizedAssetManager.sol";


/**
 * @title Asset Transfer Rights contract
 *
 * @author PWN Finance
 *
 * @notice This contract represents tokenized transfer rights of underlying asset (ATR token)
 * ATR token can be used in lending protocols instead of an underlying asset
 */
contract AssetTransferRights is WhitelistManager, ERC721, TokenizedAssetManager  {
	using MultiToken for MultiToken.Asset;


	/*----------------------------------------------------------*|
	|*  # VARIABLES & CONSTANTS DEFINITIONS                     *|
	|*----------------------------------------------------------*/

	/**
	 * EIP-1271 valid signature magic value
	 */
	bytes4 constant internal EIP1271_VALID_SIGNATURE = 0x1626ba7e;

	/**
	 * EIP-712 recipient permission struct type hash
	 */
	bytes32 constant internal RECIPIENT_PERMISSION_TYPEHASH = keccak256(
		"RecipientPermission(address owner,address wallet,uint40 expiration,bytes32 nonce)"
	);

	// mainnet
	bytes32 constant internal GNOSIS_SAFE_SINGLETON_ADDRESS = 0x000000000000000000000000d9Db270c1B5E3Bd161E8c8503c55cEABeE709552;

	uint256 constant internal GUARD_STORAGE_SLOT = 0x4a204f620c8c5ccdca3fd54d003badd85ba500436a431f0cbda4f558c93c34c8;
	address constant internal SENTINEL_MODULES = address(0x1);

	/**
	 * @notice Struct representing recipient permission to transfer asset to its PWN Wallet
	 *
	 * @param owner Wallet owner which is also a permission signer
	 * @param wallet Address of PWN Wallet to which is the permission granted
	 * @param expiration Permission expiration timestamp in seconds
	 *        0 value means permission cannot expire
	 * @param nonce Additional nonce to distinguish between same permissions
	 */
	struct RecipientPermission {
		address owner;
		address wallet;
		uint40 expiration;
		bytes32 nonce;
	}

	/**
	 * @notice Last minted token id
	 *
	 * @dev First used token id is 1
	 * If lastTokenId == 0, there is no ATR token minted yet
	 */
	uint256 public lastTokenId;

	/**
	 * Mapping of revoked recipient permissions by recipient permission struct typed hash
	 */
	mapping (bytes32 => bool) public revokedPermissions;

	IAssetTransferRightsGuard public atrGuard;


	/*----------------------------------------------------------*|
	|*  # EVENTS & ERRORS DEFINITIONS                           *|
	|*----------------------------------------------------------*/

	event RecipientPermissionRevoked(bytes32 indexed permissionHash);


	/*----------------------------------------------------------*|
	|*  # MODIFIERS                                             *|
	|*----------------------------------------------------------*/

	// No modifiers defined


	/*----------------------------------------------------------*|
	|*  # CONSTRUCTOR                                           *|
	|*----------------------------------------------------------*/

	constructor() WhitelistManager() ERC721("Asset Transfer Rights", "ATR") {

	}


	/*----------------------------------------------------------*|
	|*  # ASSET TRANSFER RIGHTS TOKEN                           *|
	|*----------------------------------------------------------*/

	/**
	 * @notice Tokenize given assets transfer rights and mint ATR token
	 *
	 * @dev Requirements:
	 *
	 * - caller has to be PWNWallet
	 * - cannot tokenize transfer rights of ATR token
	 * - in case whitelist is used, asset has to be whitelisted
	 * - cannot tokenize invalid asset. See {MultiToken-isValid}
	 * - cannot have operator set for that asset contract (setApprovalForAll) (ERC721 / ERC1155)
	 * - in case of ERC721 assets, cannot tokenize approved asset, but other tokens can be approved
	 * - in case of ERC20 assets, asset cannot have any approval
	 *
	 * @param asset Asset struct defined in MultiToken library. See {MultiToken-Asset}
	 *
	 * @return Id of newly minted ATR token
	 */
	function mintAssetTransferRightsToken(MultiToken.Asset memory asset) public returns (uint256) {
		// Check that asset address is not zero address
		require(asset.assetAddress != address(0), "Attempting to tokenize zero address asset");

		// Check that asset address is not ATR contract address
		require(asset.assetAddress != address(this), "Attempting to tokenize ATR token");

		// Check that address is whitelisted
		require(useWhitelist == false || isWhitelisted[asset.assetAddress] == true, "Asset is not whitelisted");

		// Check that provided asset category is correct
		if (asset.category == MultiToken.Category.ERC20) {

			if (ERC165Checker.supportsERC165(asset.assetAddress)) {
				require(ERC165Checker.supportsERC165InterfaceUnchecked(asset.assetAddress, type(IERC20).interfaceId), "Invalid provided category");

			} else {

				// Fallback check for ERC20 tokens not implementing ERC165
				try IERC20(asset.assetAddress).totalSupply() returns (uint256) {
				} catch { revert("Invalid provided category"); }

			}

		} else if (asset.category == MultiToken.Category.ERC721) {
			require(ERC165Checker.supportsInterface(asset.assetAddress, type(IERC721).interfaceId), "Invalid provided category");

		} else if (asset.category == MultiToken.Category.ERC1155) {
			require(ERC165Checker.supportsInterface(asset.assetAddress, type(IERC1155).interfaceId), "Invalid provided category");

		} else {
			revert("Invalid provided category");
		}

		// Check that msg.sender is PWNWallet
		require(_isValidSafe(msg.sender) == true, "Caller is not a PWN Wallet");

		// Check that given asset is valid
		require(asset.isValid(), "MultiToken.Asset is not valid");

		// Check that asset collection doesn't have approvals
		require(atrGuard.hasOperatorFor(msg.sender, asset.assetAddress) == false, "Some asset from collection has an approval");

		// Check that ERC721 asset don't have approval
		if (asset.category == MultiToken.Category.ERC721) {
			address approved = IERC721(asset.assetAddress).getApproved(asset.id);
			require(approved == address(0), "Tokenized asset has an approved address");
		}

		// Check if asset can be tokenized
		require(_canBeTokenized(msg.sender, asset), "Insufficient balance to tokenize");

		// Set ATR token id
		uint256 atrTokenId = ++lastTokenId;

		// Store asset data
		_storeTokenizedAsset(atrTokenId, asset);

		// Update tokenized balance
		_increaseTokenizedBalance(atrTokenId, msg.sender, asset);

		// Mint ATR token
		_mint(msg.sender, atrTokenId);

		return atrTokenId;
	}

	/**
	 * @notice Tokenize given asset batch transfer rights and mint ATR tokens
	 *
	 * @dev Function will iterate over given list and all `mintAssetTransferRightsToken` on each of them.
	 * Requirements: See {AssetTransferRights-mintAssetTransferRightsToken}.
	 *
	 * @param assets List of assets to tokenize theirs transfer rights
	 */
	function mintAssetTransferRightsTokenBatch(MultiToken.Asset[] calldata assets) external {
		for (uint256 i; i < assets.length; ++i) {
			mintAssetTransferRightsToken(assets[i]);
		}
	}

	/**
	 * @notice Burn ATR token and "untokenize" that assets transfer rights
	 *
	 * @dev Token owner can burn the token if it's in the same wallet as tokenized asset or via flag in `transferAssetFrom` function.
	 *
	 * Requirements:
	 *
	 * - caller has to be ATR token owner
	 * - ATR token has to be in the same wallet as tokenized asset
	 *
	 * @param atrTokenId ATR token id which should be burned
	 */
	function burnAssetTransferRightsToken(uint256 atrTokenId) public {
		// Load asset
		MultiToken.Asset memory asset = _assets[atrTokenId];

		// Check that token is indeed tokenized
		require(asset.assetAddress != address(0), "Asset transfer rights are not tokenized");

		// Check that caller is ATR token owner
		require(ownerOf(atrTokenId) == msg.sender, "Caller is not ATR token owner");

		// Check that ATR token is in the same wallet as tokenized asset
		// Without this condition ATR contract would not know from which address to remove the ATR token
		require(asset.balanceOf(msg.sender) >= asset.amount, "Insufficient balance of a tokenize asset");

		// Update tokenized balance
		require(_decreaseTokenizedBalance(atrTokenId, msg.sender, asset), "Tokenized asset is not in a wallet");

		// Clear asset data
		_clearTokenizedAsset(atrTokenId);

		// Burn ATR token
		_burn(atrTokenId);
	}

	/**
	 * @notice Burn ATR token list and "untokenize" assets transfer rights
	 *
	 * @dev Function will iterate over given list and all `burnAssetTransferRightsToken` on each of them.
	 *
	 * Requirements: See {AssetTransferRights-burnAssetTransferRightsToken}.
	 *
	 * @param atrTokenIds ATR token id list which should be burned
	 *
	 */
	function burnAssetTransferRightsTokenBatch(uint256[] calldata atrTokenIds) external {
		for (uint256 i; i < atrTokenIds.length; ++i) {
			burnAssetTransferRightsToken(atrTokenIds[i]);
		}
	}


	/*----------------------------------------------------------*|
	|*  # TRANSFER ASSET WITH ATR TOKEN                         *|
	|*----------------------------------------------------------*/

	/**
	 * @notice Transfer assets via ATR token to caller
	 *
	 * @dev Asset can be transferred only to caller
	 * Argument `burnToken` will burn the ATR token and transfer asset to any address (don't have to be PWN Wallet).
	 * Caller has to be ATR token owner.
	 *
	 * Requirements:
	 *
	 * - caller has to be ATR token owner
	 * - if `burnToken` is false, caller has to be PWN Wallet, otherwise it could be any address
	 * - if `burnToken` is false, caller must not have any approvals for asset contract
	 *
	 * @param from PWN Wallet address from which to transfer asset
	 * @param atrTokenId ATR token id which is used for the transfer
	 * @param burnToken Flag to burn ATR token in the same transaction
	 */
	function transferAssetFrom( // TODO: Rename to claimAssetFrom()
		address from,
		uint256 atrTokenId,
		bool burnToken
	) external {
		// Process asset transfer
		MultiToken.Asset memory asset = _processTransferAssetFrom(from, msg.sender, atrTokenId, burnToken);

		bytes memory data = asset.transferAssetCalldata(from, msg.sender);

		// Transfer asset from `from` wallet
		ModuleManager(from).execTransactionFromModule(asset.assetAddress, 0, data, Enum.Operation.Call);
	}

	/**
	 * @notice Transfer assets via ATR token to recipient wallet
	 *
	 * @dev Asset can be transferred only to wallet that granted the permission.
	 * Argument `burnToken` will burn the ATR token and transfer asset to any address (don't have to be PWN Wallet).
	 * Caller has to be ATR token owner.
	 *
	 * Requirements:
	 *
	 * - caller has to be ATR token owner
	 * - if `burnToken` is false, recipient has to be PWN Wallet, otherwise it could be any address
	 * - if `burnToken` is false, recipient must not have any approvals for asset contract
	 *
	 * @param from PWN Wallet address from which to transfer asset
	 * @param atrTokenId ATR token id which is used for the transfer
	 * @param burnToken Flag to burn ATR token in the same transaction
	 * @param permission `RecipientPermission` struct of permission data
	 * @param permissionSignature Signed `RecipientPermission` struct signed by recipient
	 */
	function transferAssetWithPermissionFrom(
		address from,
		uint256 atrTokenId,
		bool burnToken,
		RecipientPermission calldata permission,
		bytes calldata permissionSignature
	) external {
		// Process permission signature
		_processRecipientPermission(permission, permissionSignature);

		// Process asset transfer
		MultiToken.Asset memory asset = _processTransferAssetFrom(from, permission.wallet, atrTokenId, burnToken);

		if (burnToken == false) {
			// Check that stated wallet owner is indeed wallet owner
			require(Ownable(permission.wallet).owner() == permission.owner, "Permission signer is not wallet owner");
		}

		bytes memory data = asset.transferAssetCalldata(from, permission.wallet);

		// Transfer asset from `from` wallet
		ModuleManager(from).execTransactionFromModule(asset.assetAddress, 0, data, Enum.Operation.Call);
	}

	/**
	 * @notice Revoke granted recipient permission to transfer asset to its PWN Wallet
	 *
	 * @dev Caller has to be permission signer
	 *
	 * @param permissionHash EIP-712 Structured hash of `RecipientPermission` struct
	 * @param permissionSignature Signed `permissionHash` by wallet owner
	 */
	function revokeRecipientPermission(
		bytes32 permissionHash,
		bytes calldata permissionSignature
	) external {
		// Check that caller is permission signer
		require(ECDSA.recover(permissionHash, permissionSignature) == msg.sender, "Sender is not a recipient permission signer");

		// Check that permission is not yet revoked
		require(revokedPermissions[permissionHash] == false, "Recipient permission is revoked");

		// Revoke permission
		revokedPermissions[permissionHash] = true;

		// Emit event
		emit RecipientPermissionRevoked(permissionHash);
	}


	/*----------------------------------------------------------*|
	|*  # SETTERS                                               *|
	|*----------------------------------------------------------*/

	/// TODO: Doc
	function setAssetTransferRightsGuard(address _atrGuard) external onlyOwner {
		atrGuard = IAssetTransferRightsGuard(_atrGuard);
	}


	/*----------------------------------------------------------*|
	|*  # VIEW                                                  *|
	|*----------------------------------------------------------*/

	/**
	 * @dev Compute recipient permission struct hash according to EIP-712
	 *
	 * @param permission RecipientPermission struct to compute hash from
	 *
	 * @return EIP-712 compliant recipient permission hash
	 */
	function recipientPermissionHash(RecipientPermission calldata permission) public view returns (bytes32) {
		return keccak256(abi.encodePacked(
			"\x19\x01",
			// Domain separator is composing to prevent replay attack in case of an Ethereum fork
			keccak256(abi.encode(
				keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
				keccak256(bytes("ATR")), // ?
				keccak256(bytes("0.1")),
				block.chainid,
				address(this)
			)),
			keccak256(abi.encode(
				RECIPIENT_PERMISSION_TYPEHASH,
				permission.owner,
				permission.wallet,
				permission.expiration,
				permission.nonce
			))
		));
	}


	/*----------------------------------------------------------*|
	|*  # PRIVATE                                               *|
	|*----------------------------------------------------------*/

	/**
	 * @dev Process recipient permission checks
	 * Signer has to be stated in a `RecipientPermission` struct as an owner
	 *
	 * @param permission Provided `RecipientPermission` struct to check
	 * @param permissionSignature Signed `RecipientPermission` struct by wallet owner
	 */
	function _processRecipientPermission(
		RecipientPermission calldata permission,
		bytes calldata permissionSignature
	) private {
		// Check that permission is not expired
		require(permission.expiration == 0 || block.timestamp < permission.expiration, "Recipient permission is expired");

		// Compute EIP-712 structured data hash
		bytes32 permissionHash = recipientPermissionHash(permission);

		// Check that permission is not revoked
		require(revokedPermissions[permissionHash] == false, "Recipient permission is revoked");

		// Check valid signature
		if (permission.owner.code.length > 0) {
			require(IERC1271(permission.owner).isValidSignature(permissionHash, permissionSignature) == EIP1271_VALID_SIGNATURE, "Signature on behalf of contract is invalid");
		} else {
			require(ECDSA.recover(permissionHash, permissionSignature) == permission.owner, "Permission signer is not stated as wallet owner");
		}

		// Mark used permission as revoked
		revokedPermissions[permissionHash] = true;

		// Emit event
		emit RecipientPermissionRevoked(permissionHash);
	}

	/**
	 * @dev Process internal state of asset transfer
	 *
	 * @param from Address from which an asset will be transferred
	 * @param to Address to which an asset will be transferred
	 * @param atrTokenId Id of an ATR token which represents the underlying asset
	 * @param burnToken Flag to burn ATR token in the same transaction
	 */
	function _processTransferAssetFrom(
		address from,
		address to,
		uint256 atrTokenId,
		bool burnToken
	) private returns (MultiToken.Asset memory) {
		// Load asset
		MultiToken.Asset memory asset = _assets[atrTokenId];

		// Check that transferring to different address
		require(from != to, "Attempting to transfer asset to the same address");

		// Check that asset transfer rights are tokenized
		require(asset.assetAddress != address(0), "Transfer rights are not tokenized");

		// Check that sender is ATR token owner
		require(ownerOf(atrTokenId) == msg.sender, "Caller is not ATR token owner");

		// Update tokenized balance
		require(_decreaseTokenizedBalance(atrTokenId, from, asset), "Asset is not in a target wallet");

		if (burnToken == true) {
			// Burn the ATR token
			_clearTokenizedAsset(atrTokenId);

			_burn(atrTokenId);
		} else {
			// Fail if recipient is not PWNWallet
			require(_isValidSafe(to) == true, "Attempting to transfer asset to non PWN Wallet address");

			// Check that recipient doesn't have approvals for the token collection
			require(atrGuard.hasOperatorFor(to, asset.assetAddress) == false, "Receiver has approvals set for an asset");

			// Update tokenized balance
			_increaseTokenizedBalance(atrTokenId, to, asset);
		}

		return asset;
	}

	/// TODO: Doc
	function _isValidSafe(address safe) private view returns (bool) {
		// Check that address is GnosisSafeProxy
		// Need to hash bytes arrays first, because solidity cannot compare byte arrays directly
		if (keccak256(type(GnosisSafeProxy).runtimeCode) != keccak256(address(safe).code))
			return false;

		// TODO: List of supported singletons?
		// Check that proxy has correct singleton set
		bytes memory singletonValue = StorageAccessible(safe).getStorageAt(0, 1);
		if (bytes32(singletonValue) != GNOSIS_SAFE_SINGLETON_ADDRESS)
			return false;

		// Check that safe has correct guard set
		bytes memory guardValue = StorageAccessible(safe).getStorageAt(GUARD_STORAGE_SLOT, 1);
		if (bytes32(guardValue) != bytes32(bytes20(address(atrGuard))))
			return false;

		// Check that safe has correct module set
		if (ModuleManager(safe).isModuleEnabled(address(this)) == false)
			return false;

		// Check that safe has only one module
		(address[] memory modules, ) = ModuleManager(safe).getModulesPaginated(SENTINEL_MODULES, 2);
		if (modules.length > 1)
			return false;

		// All checks passed
		return true;
	}

}
