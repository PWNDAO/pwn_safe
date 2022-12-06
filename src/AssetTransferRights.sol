// SPDX-License-Identifier: GPL-3.0-only
pragma solidity 0.8.15;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/ERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155.sol";
import "openzeppelin-contracts/contracts/utils/introspection/ERC165Checker.sol";

import "safe-contracts/common/Enum.sol";
import "safe-contracts/GnosisSafe.sol";

import "MultiToken/MultiToken.sol";

import "./guard/IAssetTransferRightsGuard.sol";
import "./managers/AssetTransferRightsGuardManager.sol";
import "./managers/PWNSafeValidatorManager.sol";
import "./managers/RecipientPermissionManager.sol";
import "./managers/TokenizedAssetManager.sol";
import "./managers/WhitelistManager.sol";


/**
 * @title Asset Transfer Rights contract
 * @notice This contract represents tokenized transfer rights of underlying asset (ATR token).
 *         ATR token can be used in lending protocols instead of an underlying asset.
 */
contract AssetTransferRights is
	Ownable,
	WhitelistManager,
	AssetTransferRightsGuardManager,
	PWNSafeValidatorManager,
	TokenizedAssetManager,
	RecipientPermissionManager,
	ERC721
{
	using MultiToken for MultiToken.Asset;
	using ERC165Checker for address;


	/*----------------------------------------------------------*|
	|*  # VARIABLES & CONSTANTS DEFINITIONS                     *|
	|*----------------------------------------------------------*/

	string public constant VERSION = "0.1.0";

	/**
	 * @notice Last minted token id.
	 * @dev First used token id is 1.
	 *      If `lastTokenId` == 0, there is no ATR token minted yet.
	 */
	uint256 public lastTokenId;

	/**
	 * @dev ATR token metadata URI with `{id}` placeholder.
	 */
	string private _metadataUri;


	/*----------------------------------------------------------*|
	|*  # EVENTS & ERRORS DEFINITIONS                           *|
	|*----------------------------------------------------------*/

	// No event nor error defined


	/*----------------------------------------------------------*|
	|*  # MODIFIERS                                             *|
	|*----------------------------------------------------------*/

	modifier onlyGuardManager override {
		_checkOwner();
		_;
	}

	modifier onlyWhitelistManager override {
		_checkOwner();
		_;
	}

	modifier onlyValidatorManager override {
		_checkOwner();
		_;
	}


	/*----------------------------------------------------------*|
	|*  # CONSTRUCTOR                                           *|
	|*----------------------------------------------------------*/

	constructor()
		Ownable()
		ERC721("Asset Transfer Rights", "ATR")
	{
		useWhitelist = true;
	}


	/*----------------------------------------------------------*|
	|*  # ASSET TRANSFER RIGHTS TOKEN                           *|
	|*----------------------------------------------------------*/

	/**
	 * @notice Tokenize given assets transfer rights and mint ATR token.
	 * @dev Requirements:
	 *      - caller has to be PWNSafe
	 *      - cannot tokenize transfer rights of ATR token
	 *      - in case whitelist is used, asset has to be whitelisted
	 *      - cannot tokenize invalid asset. See {MultiToken-isValid}
	 *      - cannot have operator set for that asset collection (setApprovalForAll) (ERC721 / ERC1155)
	 *      - in case of ERC721 assets, cannot tokenize approved asset, but other tokens can be approved
	 *      - in case of ERC20 assets, asset cannot have any approval
	 * @param asset Asset struct defined in MultiToken library. See {MultiToken-Asset}
	 * @return Id of newly minted ATR token
	 */
	function mintAssetTransferRightsToken(MultiToken.Asset memory asset) public returns (uint256) {
		// Check that msg.sender is PWNSafe
		require(safeValidator.isValidSafe(msg.sender) == true, "Caller is not a PWNSafe");

		// Check that asset address is not zero address
		require(asset.assetAddress != address(0), "Attempting to tokenize zero address asset");

		// Check that asset address is not ATR contract address
		require(asset.assetAddress != address(this), "Attempting to tokenize ATR token");

		// Check that address is whitelisted
		require(useWhitelist == false || isWhitelisted[asset.assetAddress] == true, "Asset is not whitelisted");

		// Check that provided asset category is correct
		if (asset.category == MultiToken.Category.ERC20) {

			if (asset.assetAddress.supportsERC165()) {
				require(asset.assetAddress.supportsERC165InterfaceUnchecked(type(IERC20).interfaceId), "Invalid provided category");

			} else {

				// Fallback check for ERC20 tokens not implementing ERC165
				try IERC20(asset.assetAddress).totalSupply() returns (uint256) {
				} catch { revert("Invalid provided category"); }

			}

		} else if (asset.category == MultiToken.Category.ERC721) {
			require(asset.assetAddress.supportsInterface(type(IERC721).interfaceId), "Invalid provided category");

		} else if (asset.category == MultiToken.Category.ERC1155) {
			require(asset.assetAddress.supportsInterface(type(IERC1155).interfaceId), "Invalid provided category");

		} else {
			revert("Invalid provided category");
		}

		// Check that given asset is valid
		require(asset.isValid(), "Asset is not valid");

		// Check that asset collection doesn't have approvals
		require(atrGuard.hasOperatorFor(msg.sender, asset.assetAddress) == false, "Some asset from collection has an approval");

		// Check that ERC721 asset don't have approval
		if (asset.category == MultiToken.Category.ERC721) {
			address approved = IERC721(asset.assetAddress).getApproved(asset.id);
			require(approved == address(0), "Asset has an approved address");
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
	 * @notice Tokenize given asset batch transfer rights and mint ATR tokens.
	 * @dev Function will iterate over given list and call `mintAssetTransferRightsToken` on each of them.
	 *      Requirements: See {AssetTransferRights-mintAssetTransferRightsToken}.
	 * @param assets List of assets to tokenize their transfer rights.
	 */
	function mintAssetTransferRightsTokenBatch(MultiToken.Asset[] calldata assets) external {
		for (uint256 i; i < assets.length; ++i) {
			mintAssetTransferRightsToken(assets[i]);
		}
	}

	/**
	 * @notice Burn ATR token and "untokenize" that assets transfer rights.
	 * @dev Token owner can burn the token if it's in the same safe as tokenized asset or via flag in `claimAssetFrom` function.
	 *      Requirements:
	 *      - caller has to be ATR token owner
	 *      - safe has to be a tokenized asset owner or ATR token has to be invalid (after recovery from e.g. stalking attack)
	 * @param atrTokenId ATR token id which should be burned.
	 */
	function burnAssetTransferRightsToken(uint256 atrTokenId) public {
		// Load asset
		MultiToken.Asset memory asset = assets[atrTokenId];

		// Check that token is indeed tokenized
		require(asset.assetAddress != address(0), "Asset transfer rights are not tokenized");

		// Check that caller is ATR token owner
		require(ownerOf(atrTokenId) == msg.sender, "Caller is not ATR token owner");

		if (isInvalid[atrTokenId] == false) {

			// Is this part necessary? -----
			require(asset.balanceOf(msg.sender) >= asset.amount, "Insufficient balance of a tokenize asset");
			// -----------------------------

			// Update tokenized balance
			require(_decreaseTokenizedBalance(atrTokenId, msg.sender, asset), "Tokenized asset is not in a safe");
		}

		// Clear asset data
		_clearTokenizedAsset(atrTokenId);

		// Burn ATR token
		_burn(atrTokenId);
	}

	/**
	 * @notice Burn ATR token list and "untokenize" assets transfer rights.
	 * @dev Function will iterate over given list and all `burnAssetTransferRightsToken` on each of them.
	 *      Requirements: See {AssetTransferRights-burnAssetTransferRightsToken}.
	 * @param atrTokenIds ATR token id list which should be burned
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
	 * @notice Transfer assets via ATR token to a caller.
	 * @dev Asset can be transferred only to a callers address.
	 *      Flag `burnToken` will burn the ATR token and transfer asset to any address (don't have to be PWNSafe).
	 *      Requirements:
	 *      - caller has to be an ATR token owner
	 *      - if `burnToken` is false, caller has to be PWNSafe, otherwise it could be any address
	 *      - if `burnToken` is false, caller must not have any approvals for asset collection
	 * @param from PWNSafe address from which to transfer asset.
	 * @param atrTokenId ATR token id which is used for the transfer.
	 * @param burnToken Flag to burn an ATR token in the same transaction.
	 */
	function claimAssetFrom(
		address payable from,
		uint256 atrTokenId,
		bool burnToken
	) external {
		// Load asset
		MultiToken.Asset memory asset = assets[atrTokenId];

		_initialChecks(asset, from, msg.sender, atrTokenId);

		// Process asset transfer
		_processTransferAssetFrom(asset, from, msg.sender, atrTokenId, burnToken);
	}

	/**
	 * @notice Transfer assets via ATR token to any address.
	 * @dev Asset can be transferred to any address, but needs to have recipient permission.
	 *      Permission can be granted on-chain, through off-chain signature or via ERC1271.
	 *      Flag `burnToken` will burn the ATR token and transfer asset to any address (don't have to be PWNSafe).
	 *      Requirements:
	 *      - caller has to be an ATR token owner
	 *      - if `burnToken` is false, caller has to be PWNSafe, otherwise it could be any address
	 *      - if `burnToken` is false, caller must not have any approvals for asset collection
	 *      - caller has to have recipients permission (granted on-chain, signed off-chain or via ERC1271)
	 * @param from PWNSafe address from which to transfer asset.
	 * @param atrTokenId ATR token id which is used for the transfer.
	 * @param burnToken Flag to burn an ATR token in the same transaction.
	 * @param permission Struct representing recipient permission. See {RecipientPermissionManager-RecipientPermission}.
	 * @param permissionSignature Signature of permission struct hash. In case of on-chain permission or when ERC1271 don't need it, pass empty data.
	 */
	function transferAssetFrom(
		address payable from,
		uint256 atrTokenId,
		bool burnToken,
		RecipientPermission memory permission,
		bytes calldata permissionSignature
	) external {
		// Load asset
		MultiToken.Asset memory asset = assets[atrTokenId];

		_initialChecks(asset, from, permission.recipient, atrTokenId);

		// Check valid permission
		_checkValidPermission(msg.sender, asset, permission, permissionSignature);

		// Process asset transfer
		_processTransferAssetFrom(asset, from, permission.recipient, atrTokenId, burnToken);
	}

	/**
	 * @dev Check basic transfer conditions.
	 * @param asset Struct representing asset to be transferred. See {MultiToken-Asset}.
	 * @param from Address from which an asset will be transferred.
	 * @param to Address to which an asset will be transferred.
	 * @param atrTokenId Id of an ATR token which represents the underlying asset.
	 */
	function _initialChecks(
		MultiToken.Asset memory asset,
		address payable from,
		address to,
		uint256 atrTokenId
	) private view {
		// Check that transferring to different address
		require(from != to, "Attempting to transfer asset to the same address");

		// Check that asset transfer rights are tokenized
		require(asset.assetAddress != address(0), "Transfer rights are not tokenized");

		// Check that sender is ATR token owner
		require(ownerOf(atrTokenId) == msg.sender, "Caller is not ATR token owner");
	}

	/**
	 * @dev Process internal state of an asset transfer and execute it.
	 * @param asset Struct representing asset to be transferred. See {MultiToken-Asset}.
	 * @param from Address from which an asset will be transferred.
	 * @param to Address to which an asset will be transferred.
	 * @param atrTokenId Id of an ATR token which represents the underlying asset.
	 * @param burnToken Flag to burn ATR token in the same transaction.
	 */
	function _processTransferAssetFrom(
		MultiToken.Asset memory asset,
		address payable from,
		address to,
		uint256 atrTokenId,
		bool burnToken
	) private {
		// Update tokenized balance (would fail for invalid ATR token)
		require(_decreaseTokenizedBalance(atrTokenId, from, asset), "Asset is not in a target safe");

		if (burnToken == true) {
			// Burn the ATR token
			_clearTokenizedAsset(atrTokenId);

			_burn(atrTokenId);
		} else {
			// Fail if recipient is not PWNSafe
			require(safeValidator.isValidSafe(to) == true, "Attempting to transfer asset to non PWNSafe address");

			// Check that recipient doesn't have approvals for the token collection
			require(atrGuard.hasOperatorFor(to, asset.assetAddress) == false, "Receiver has approvals set for an asset");

			// Update tokenized balance
			_increaseTokenizedBalance(atrTokenId, to, asset);
		}

		bytes memory data = asset.transferAssetCalldata(from, to);

		// Transfer asset from `from` safe
		GnosisSafe(from).execTransactionFromModule(asset.assetAddress, 0, data, Enum.Operation.Call);
	}


	/*----------------------------------------------------------*|
	|*  # ATR TOKEN METADATA                                    *|
	|*----------------------------------------------------------*/

	/**
     * @dev See {IERC721Metadata-tokenURI}.
     */
	function tokenURI(uint256 tokenId) override public view returns (string memory) {
		_requireMinted(tokenId);
		return _metadataUri;
	}

	/**
	 * @notice Set new ATR token metadata URI.
	 * @param metadataUri New metadata URI.
	 */
	function setMetadataUri(string memory metadataUri) external onlyOwner {
		_metadataUri = metadataUri;
	}

}
