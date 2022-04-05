// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@pwnfinance/multitoken/contracts/MultiToken.sol";
import "./IPWNWallet.sol";
import "./PWNWalletFactory.sol";

/**
 * @title Asset Transfer Rights contract
 * @author PWN Finance
 * @notice This contract represents tokenized transfer rights of underlying asset (ATR token)
 * ATR token can be used in lending protocols instead of an underlying asset
 */
contract AssetTransferRights is ERC721 {
	using EnumerableSet for EnumerableSet.UintSet;
	using MultiToken for MultiToken.Asset;


	/*----------------------------------------------------------*|
	|*  # VARIABLES & CONSTANTS DEFINITIONS                     *|
	|*----------------------------------------------------------*/

	/**
	 * @notice Last minted token id
	 * @dev First used token id is 1
	 * If lastTokenId == 0, there is no ATR token minted yet
	 */
	uint256 public lastTokenId;

	/**
	 * @notice Address of pwn wallet factory
	 * @dev Wallet factory is used to determine valid pwn wallet addresses
	 */
	PWNWalletFactory public walletFactory;

	/**
	 * @notice Mapping of ATR token id to underlying asset
	 * @dev (ATR token id => Asset)
	 */
	mapping (uint256 => MultiToken.Asset) internal _assets;

	/**
	 * @notice Mapping of address to set of ATR ids, that belongs to assets in the addresses pwn wallet
	 * @dev The ATR token itself doesn't have to be in the wallet
	 * Used in PWNWallet to enumerate over all tokenized assets after execution of arbitrary calldata
	 * (owner => set of ATR token ids representing tokenized assets currently in owners wallet)
	 */
	mapping (address => EnumerableSet.UintSet) internal _ownedAssetATRIds;

	/**
	 * @notice Number of tokenized assets from asset contract in a wallet
	 * @dev Used in PWNWallet to check if owner can call setApprovalForAll on given asset contract
	 * (owner => tokenAddress => number of tokenized assets from given asset contract currently in owners wallet)
	 */
	mapping (address => mapping (address => uint256)) internal _ownedFromCollection;


	/*----------------------------------------------------------*|
	|*  # EVENTS & ERRORS DEFINITIONS                           *|
	|*----------------------------------------------------------*/

	// No events nor error defined


	/*----------------------------------------------------------*|
	|*  # MODIFIERS                                             *|
	|*----------------------------------------------------------*/

	// No modifiers defined


	/*----------------------------------------------------------*|
	|*  # CONSTRUCTOR                                           *|
	|*----------------------------------------------------------*/

	/**
	 * @notice Contract constructor
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
	 * @param asset Asset struct defined in MultiToken library. See {MultiToken-Asset}
	 *
	 * Requirements:
	 *
	 * - caller has to be PWNWallet
	 * - cannot tokenize invalid asset. See {MultiToken-isValid}
	 * - cannot have operator set for that asset contract (setApprovalForAll) (ERC721 / ERC1155)
	 * - in case of ERC721 assets, cannot tokenize approved asset, but other tokens can be approved
	 * - in case of ERC20 assets, asset cannot have any approval
	 */
	function mintAssetTransferRightsToken(MultiToken.Asset memory asset) external {
		// Check that asset address is not zero address
		require(asset.assetAddress != address(0), "Attempting to tokenize zero address asset");

		// Check that msg.sender is PWNWallet
		require(walletFactory.isValidWallet(msg.sender) == true, "Caller is not a PWN Wallet");

		// Check that amount is correctly set
		require(asset.isValid(), "MultiToken.Asset is not valid");

		// Check that asset collection doesn't have approvals
		require(IPWNWallet(msg.sender).hasApprovalsFor(asset.assetAddress) == false, "Some asset from collection has an approval");

		// Check that tokenized asset don't have approval
		// ERC721 operator can approve concrete asset without triggering any action in wallet nor ATR contract
		// Without this check it would be possible to tokenize approved ERC721 asset
		if (asset.category == MultiToken.Category.ERC721) {
			address approved = IERC721(asset.assetAddress).getApproved(asset.id);
			require(approved == address(0), "Tokenized asset has an approved address");
		}

		// Check if asset can be tokenized
		uint256 balance = asset.balanceOf(msg.sender);
		require(balance >= asset.amount, "Insufficient balance to tokenize");

		unchecked {
			balance -= asset.amount;
		}

		uint256[] memory atrs = ownedAssetATRIds();
		for (uint256 i = 0; i < atrs.length; ++i) {
			MultiToken.Asset memory _asset = getAsset(atrs[i]);

			if (asset.isSameAs(_asset)) {
				require(balance >= _asset.amount, "Insufficient balance to tokenize");
				balance -= _asset.amount;
			}
		}

		uint256 atrTokenId = ++lastTokenId;

		// Store asset data
		_assets[atrTokenId] = asset;

		// Update internal state
		_ownedAssetATRIds[msg.sender].add(atrTokenId);
		_ownedFromCollection[msg.sender][asset.assetAddress] += 1;

		// Mint ATR token
		_mint(msg.sender, atrTokenId);
	}

	/**
	 * @notice Burn ATR token and "untokenize" that assets transfer rights
	 * @dev Token owner can burn the token if it's in the same wallet as tokenized asset or via flag in `transferAssetFrom` function
	 *
	 * @param atrTokenId ATR token id which should be burned
	 *
	 * Requirements:
	 *
	 * - caller has to be ATR token owner
	 * - ATR token has to be in the same wallet as tokenized asset
	 */
	function burnAssetTransferRightsToken(uint256 atrTokenId) external {
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
		_assets[atrTokenId] = MultiToken.Asset(address(0), MultiToken.Category.ERC20, 0, 0);

		// Update internal state
		require(_ownedAssetATRIds[msg.sender].remove(atrTokenId), "Tokenized asset is not in a wallet");
		_ownedFromCollection[msg.sender][asset.assetAddress] -= 1;

		// Burn ATR token
		_burn(atrTokenId);
	}


	/*----------------------------------------------------------*|
	|*  # TRANSFER ASSET WITH ATR TOKEN                         *|
	|*----------------------------------------------------------*/

	/**
	 * @notice Transfer assets via ATR token
	 * @dev Asset can be transferred only to caller (claim)
	 * Argument `burnToken` will burn the ATR token and transfer asset to any address (don't have to be PWN Wallet)
	 * Caller has to be ATR token owner
	 *
	 * @param from PWN Wallet address from which to transfer asset
	 * @param atrTokenId ATR token id which is used for the transfer
	 * @param burnToken Flag to burn ATR token in the same transaction
	 *
	 * Requirements:
	 *
	 * - caller has to be ATR token owner
	 * - if `burnToken` is false, caller has to be PWN Wallet, otherwise it could be any address
	 * - if `burnToken` is false, caller must not have any approvals for asset contract
	 */
	function transferAssetFrom(address from, uint256 atrTokenId, bool burnToken) external {
		address to = msg.sender;

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
		_ownedFromCollection[from][asset.assetAddress] -= 1;

		if (burnToken) {
			// Burn the ATR token
			_assets[atrTokenId] = MultiToken.Asset(address(0), MultiToken.Category.ERC20, 0, 0);

			_burn(atrTokenId);
		} else {
			// Fail if recipient is not PWNWallet
			require(walletFactory.isValidWallet(to) == true, "Attempting to transfer asset to non PWN Wallet address");

			// Check that recipient doesn't have approvals for the token collection
			require(IPWNWallet(to).hasApprovalsFor(asset.assetAddress) == false, "Receiver has approvals set for an asset");

			// Update internal state
			_ownedAssetATRIds[to].add(atrTokenId);
			_ownedFromCollection[to][asset.assetAddress] += 1;
		}

		IPWNWallet(from).transferAsset(asset, to);
	}


	/*----------------------------------------------------------*|
	|*  # UTILITY                                               *|
	|*----------------------------------------------------------*/

	/**
	 * @param atrTokenId ATR token id
	 * @return Underlying asset of an ATR token
	 */
	function getAsset(uint256 atrTokenId) public view returns (MultiToken.Asset memory) {
		return _assets[atrTokenId];
	}

	/**
	 * @return List of tokenized assets owned by caller represented by their ATR tokens
	 */
	function ownedAssetATRIds() public view returns (uint256[] memory) {
		return _ownedAssetATRIds[msg.sender].values();
	}

	/**
	 * @param assetAddress Address of asset contract
	 * @return Number of tokenized assets owned by caller from asset contract
	 */
	function ownedFromCollection(address assetAddress) external view returns (uint256) {
		return _ownedFromCollection[msg.sender][assetAddress];
	}

}
