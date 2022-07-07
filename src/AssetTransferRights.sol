// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableMap.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-contracts/contracts/utils/introspection/ERC165Checker.sol";
import "openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/interfaces/IERC1271.sol";
import "MultiToken/MultiToken.sol";
import "./IPWNWallet.sol";
import "./PWNWalletFactory.sol";

/**
 * @title Asset Transfer Rights contract
 *
 * @author PWN Finance
 *
 * @notice This contract represents tokenized transfer rights of underlying asset (ATR token)
 * ATR token can be used in lending protocols instead of an underlying asset
 */
contract AssetTransferRights is ERC721 {
	using EnumerableSet for EnumerableSet.UintSet;
	using EnumerableMap for EnumerableMap.UintToUintMap;
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
		"RecipientPermission(address owner,address wallet,bytes32 nonce)"
	);

	/**
	 * @notice Struct representing recipient permission to transfer asset to its PWN Wallet
	 *
	 * @param owner Wallet owner which is also a permission signer
	 * @param wallet Address of PWN Wallet to which is the permission granted
	 * @param nonce Additional nonce to distinguish same permissions
	 */
	struct RecipientPermission {
		address owner;
		address wallet;
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
	 * @notice Address of pwn wallet factory
	 *
	 * @dev Wallet factory is used to determine valid pwn wallet addresses
	 */
	PWNWalletFactory public walletFactory;

	/**
	 * @notice Mapping of ATR token id to underlying asset
	 *
	 * @dev (ATR token id => Asset)
	 */
	mapping (uint256 => MultiToken.Asset) internal _assets;

	/**
	 * @notice Mapping of address to set of ATR ids, that belongs to assets in the addresses pwn wallet
	 *
	 * @dev The ATR token itself doesn't have to be in the wallet
	 * Used in PWNWallet to enumerate over all tokenized assets after execution of arbitrary calldata
	 * (owner => set of ATR token ids representing tokenized assets currently in owners wallet)
	 */
	mapping (address => EnumerableSet.UintSet) internal _ownedAssetATRIds;

	/**
	 * @notice Balance of tokenized assets from asset contract in a wallet
	 *
	 * @dev Used in PWNWallet to check if owner can call setApprovalForAll on given asset contract
	 * (owner => asset address => asset id => balance of tokenized assets currently in owners wallet)
	 */
	mapping (address => mapping (address => EnumerableMap.UintToUintMap)) internal _ownedFromCollection;

	/**
	 * Mapping of revoked recipient permissions by recipient permission struct typed hash
	 */
	mapping (bytes32 => bool) public revokedPermissions;

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

	/**
	 * @notice Contract constructor
	 *
	 * @dev Contract will deploy its own wallet factory to not have to define setter and access rights for the setter
	 */
	constructor() ERC721("Asset Transfer Rights", "ATR") {
		walletFactory = new PWNWalletFactory(address(this));
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
	 * - cannot tokenize invalid asset. See {MultiToken-isValid}
	 * - cannot have operator set for that asset contract (setApprovalForAll) (ERC721 / ERC1155)
	 * - in case of ERC721 assets, cannot tokenize approved asset, but other tokens can be approved
	 * - in case of ERC20 assets, asset cannot have any approval
	 *
	 * @param asset Asset struct defined in MultiToken library. See {MultiToken-Asset}
	 */
	function mintAssetTransferRightsToken(MultiToken.Asset memory asset) public {
		// Check that asset address is not zero address
		require(asset.assetAddress != address(0), "Attempting to tokenize zero address asset");

		// Check that asset address is not ATR contract address
		require(asset.assetAddress != address(this), "Attempting to tokenize ATR token");

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
		require(walletFactory.isValidWallet(msg.sender) == true, "Caller is not a PWN Wallet");

		// Check that given asset is valid
		require(asset.isValid(), "MultiToken.Asset is not valid");

		// Check that asset collection doesn't have approvals
		require(IPWNWallet(msg.sender).hasApprovalsFor(asset.assetAddress) == false, "Some asset from collection has an approval");

		// Check that ERC721 asset don't have approval
		if (asset.category == MultiToken.Category.ERC721) {
			address approved = IERC721(asset.assetAddress).getApproved(asset.id);
			require(approved == address(0), "Tokenized asset has an approved address");
		}

		// Check if asset can be tokenized
		uint256 balance = asset.balanceOf(msg.sender);
		(, uint256 tokenizedBalance) = _ownedFromCollection[msg.sender][asset.assetAddress].tryGet(asset.id);
		require(balance - tokenizedBalance >= asset.amount, "Insufficient balance to tokenize");

		// Set ATR token id
		uint256 atrTokenId = ++lastTokenId;

		// Store asset data
		_assets[atrTokenId] = asset;

		// Update internal state
		_ownedAssetATRIds[msg.sender].add(atrTokenId);
		_increaseTokenizedBalance(msg.sender, asset);

		// Mint ATR token
		_mint(msg.sender, atrTokenId);
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
		MultiToken.Asset memory asset = getAsset(atrTokenId);

		// Check that token is indeed tokenized
		require(asset.assetAddress != address(0), "Asset transfer rights are not tokenized");

		// Check that caller is ATR token owner
		require(ownerOf(atrTokenId) == msg.sender, "Caller is not ATR token owner");

		// Check that ATR token is in the same wallet as tokenized asset
		// Without this condition ATR contract would not know from which address to remove the ATR token
		require(asset.balanceOf(msg.sender) >= asset.amount, "Insufficient balance of a tokenize asset");

		// Clear asset data
		_assets[atrTokenId] = MultiToken.Asset(MultiToken.Category.ERC20, address(0), 0, 0);

		// Update internal state
		require(_ownedAssetATRIds[msg.sender].remove(atrTokenId), "Tokenized asset is not in a wallet");
		_decreaseTokenizedBalance(msg.sender, asset);

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
	function transferAssetFrom(
		address from,
		uint256 atrTokenId,
		bool burnToken
	) external {
		// Process asset transfer
		MultiToken.Asset memory asset = _processTransferAssetFrom(from, msg.sender, atrTokenId, burnToken);

		// Transfer asset from `from` wallet
		IPWNWallet(from).transferAsset(asset, msg.sender);
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

		// Transfer asset from `from` wallet
		IPWNWallet(from).transferAsset(asset, permission.wallet);
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
	|*  # CHECK TOKENIZED BALANCE                               *|
	|*----------------------------------------------------------*/

	/**
	 * @dev Checks that caller has sufficient balance of tokenized assets.
	 * Fails if tokenized balance is insufficient.
	 *
	 * @param owner Address to check its tokenized balance
	 */
	function checkTokenizedBalance(address owner) external view {
		uint256[] memory atrs = ownedAssetATRIds(owner);
		for (uint256 i; i < atrs.length; ++i) {
			MultiToken.Asset memory asset = getAsset(atrs[i]);

			(, uint256 tokenizedBalance) = _ownedFromCollection[owner][asset.assetAddress].tryGet(asset.id);
			require(asset.balanceOf(owner) >= tokenizedBalance, "Insufficient tokenized balance");
		}
	}


	/*----------------------------------------------------------*|
	|*  # Confict resolution                                    *|
	|*----------------------------------------------------------*/

	/**
	 * @notice Recover PWN Wallets invalid tokenized balance
	 *
	 * @dev Invalid tokenized balance could happen only when an asset with tokenized transfer rights leaves the wallet non-standard way.
	 * This function is meant to recover PWN Wallets affected by Stalking attack.
	 * Stalking attack is type of attack where attacker transfer malicious tokenized asset to victims wallet
	 * and then transfers it away through some non-standard way, leaving wallet in state, where every call of `execution` function
	 * will fail on `Insufficient tokenized balance` error.
	 *
	 * @param owner PWN Wallet address with invalid tokenized balance
	 * @param atrTokenId ATR token id representing underyling asset in question
	 */
	function recoverInvalidTokenizedBalance(address owner, uint256 atrTokenId) external {
		// Check that asset is in callers wallet
		require(_ownedAssetATRIds[owner].contains(atrTokenId), "Asset is not in callers wallet");

		// Load asset
		MultiToken.Asset memory asset = getAsset(atrTokenId);

		// Get tokenized balance
		(, uint256 tokenizedBalance) = _ownedFromCollection[owner][asset.assetAddress].tryGet(asset.id);

		// Check if state is really invalid
		require(asset.balanceOf(owner) < tokenizedBalance, "Tokenized balance is not invalid");

		// Decrease tokenized balance
		_decreaseTokenizedBalance(owner, asset);

		// Remove ATR token id from tokenized asset set
		_ownedAssetATRIds[owner].remove(atrTokenId);
	}


	/*----------------------------------------------------------*|
	|*  # VIEW                                                  *|
	|*----------------------------------------------------------*/

	/**
	 * @param atrTokenId ATR token id
	 *
	 * @return Underlying asset of an ATR token
	 */
	function getAsset(uint256 atrTokenId) public view returns (MultiToken.Asset memory) {
		return _assets[atrTokenId];
	}

	/**
	 * @param owner PWN Wallet address in question
	 *
	 * @return List of tokenized assets owned by `owner` represented by their ATR tokens
	 */
	function ownedAssetATRIds(address owner) public view returns (uint256[] memory) {
		return _ownedAssetATRIds[owner].values();
	}

	/**
	 * @param owner PWN Wallet address in question
	 * @param assetAddress Address of asset contract
	 *
	 * @return Number of tokenized assets owned by `owner` from asset contract
	 */
	function ownedFromCollection(address owner, address assetAddress) external view returns (uint256) {
		return _ownedFromCollection[owner][assetAddress].length();
	}


	/*----------------------------------------------------------*|
	|*  # PRIVATE                                               *|
	|*----------------------------------------------------------*/

	/**
	 * @dev Increase stored tokenized asset balances per user address
	 *
	 * @param owner Address owning `asset`
	 * @param asset MultiToken Asset struct representing asset that should be added to tokenized balance
	 */
	function _increaseTokenizedBalance(
		address owner,
		MultiToken.Asset memory asset
	) private {
		EnumerableMap.UintToUintMap storage map = _ownedFromCollection[owner][asset.assetAddress];
		(, uint256 tokenizedBalance) = map.tryGet(asset.id);
		map.set(asset.id, tokenizedBalance + asset.amount);
	}

	/**
	 * @dev Decrease stored tokenized asset balances per user address
	 *
	 * @param owner Address owning `asset`
	 * @param asset MultiToken Asset struct representing asset that should be deducted from tokenized balance
	 */
	function _decreaseTokenizedBalance(
		address owner,
		MultiToken.Asset memory asset
	) private {
		EnumerableMap.UintToUintMap storage map = _ownedFromCollection[owner][asset.assetAddress];
		(, uint256 tokenizedBalance) = map.tryGet(asset.id);

		if (tokenizedBalance == asset.amount) {
			map.remove(asset.id);
		} else {
			map.set(asset.id, tokenizedBalance - asset.amount);
		}
	}

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
		// Compute EIP-712 structured data hash
		bytes32 permissionHash = keccak256(abi.encodePacked(
			"\x19\x01",
			// Domain separator is composing to prevent repay attack in case of an Ethereum fork
			keccak256(abi.encode(
				keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"),
				keccak256(bytes("ATR")), // ?
				keccak256(bytes("0.1")),
				block.chainid,
				address(this)
			)),
			// Compute recipient permission struct hash according to EIP-712
			keccak256(abi.encode(
				RECIPIENT_PERMISSION_TYPEHASH,
				permission.owner,
				permission.wallet,
				permission.nonce
			))
		));

		// Check valid signature
		if (permission.owner.code.length > 0) {
			require(IERC1271(permission.owner).isValidSignature(permissionHash, permissionSignature) == EIP1271_VALID_SIGNATURE, "Signature on behalf of contract is invalid");
		} else {
			require(ECDSA.recover(permissionHash, permissionSignature) == permission.owner, "Permission signer is not stated as wallet owner");
		}

		// Check that permission is not revoked
		require(revokedPermissions[permissionHash] == false, "Recipient permission is revoked");

		// Mark used permission as revoked
		revokedPermissions[permissionHash] = true;
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
		MultiToken.Asset memory asset = getAsset(atrTokenId);

		// Check that transferring to different address
		require(from != to, "Attempting to transfer asset to the same address");

		// Check that asset transfer rights are tokenized
		require(asset.assetAddress != address(0), "Transfer rights are not tokenized");

		// Check that sender is ATR token owner
		require(ownerOf(atrTokenId) == msg.sender, "Caller is not ATR token owner");

		// Update internal state
		require(_ownedAssetATRIds[from].remove(atrTokenId), "Asset is not in a target wallet");
		_decreaseTokenizedBalance(from, asset);

		if (burnToken == true) {
			// Burn the ATR token
			_assets[atrTokenId] = MultiToken.Asset(MultiToken.Category.ERC20, address(0), 0, 0);

			_burn(atrTokenId);
		} else {
			// Fail if recipient is not PWNWallet
			require(walletFactory.isValidWallet(to) == true, "Attempting to transfer asset to non PWN Wallet address");

			// Check that recipient doesn't have approvals for the token collection
			require(IPWNWallet(to).hasApprovalsFor(asset.assetAddress) == false, "Receiver has approvals set for an asset");

			// Update internal state
			_ownedAssetATRIds[to].add(atrTokenId);
			_increaseTokenizedBalance(to, asset);
		}

		return asset;
	}

}
