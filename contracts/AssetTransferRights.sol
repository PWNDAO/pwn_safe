// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@pwnfinance/multitoken/contracts/MultiToken.sol";
import "./IPWNWallet.sol";
import "./PWNWalletFactory.sol";


contract AssetTransferRights is ERC721 {
	using EnumerableSet for EnumerableSet.UintSet;
	using MultiToken for MultiToken.Asset;

	uint256 public lastTokenId;
	PWNWalletFactory public walletFactory;

	// Mapping of ATR token id to tokenized asset
	// (ATR token id => Asset)
	mapping (uint256 => MultiToken.Asset) internal _assets;

	// Mapping of address to set of ATR ids, that belongs to assets in the addresses pwn wallet
	// The ATR token itself doesn't have to be in the wallet
	// Used in PWNWallet to enumerate over all tokenized assets after arbitrary execution
	// (owner => set of ATR token ids representing tokenized assets currently in owners wallet)
	mapping (address => EnumerableSet.UintSet) internal _ownedAssetATRIds;


	constructor() ERC721("Asset Transfer Rights", "ATR") {
		walletFactory = new PWNWalletFactory(address(this));
	}


	/*----------------------------------------------------------*|
	|*  # Asset transfer rights token                           *|
	|*----------------------------------------------------------*/

	// Tokenize given assets transfer rights
	function mintAssetTransferRightsToken(MultiToken.Asset memory asset) external {
		// Check that token address is not zero address
		require(asset.assetAddress != address(0), "Cannot tokenize zero address asset");

		// Check that msg.sender is PWNWallet
		require(walletFactory.isValidWallet(msg.sender) == true, "Mint is permitted only from PWN Wallet");

		// Check that amount is correctly set
		require(asset.amount > 0, "Amount has to be bigger than zero");

		// Check if asset can be tokenized
		uint256 balance = asset.balanceOf(msg.sender);
		require(balance >= asset.amount, "Not enough balance to tokenize asset transfer rights");

		unchecked {
			balance -= asset.amount;
		}

		uint256[] memory atrs = ownedAssetATRIds();
		for (uint256 i = 0; i < atrs.length; ++i) {
			MultiToken.Asset memory _asset = getAsset(atrs[i]);

			if (areEqual(_asset, asset)) {
				require(balance >= _asset.amount, "Not enough balance to tokenize asset transfer rights");
				balance -= _asset.amount;
			}
		}

		uint256 atrTokenId = ++lastTokenId;

		// Store asset data
		_assets[atrTokenId] = asset;
		_ownedAssetATRIds[msg.sender].add(atrTokenId);

		// Mint ATR token
		_mint(msg.sender, atrTokenId);
	}

	// Burn ATR token and "untokenize" that assets transfer rights
	// Token owner can burn the token if it's in the same wallet as tokenized asset or via flag in `transferAssetFrom` function
	function burnAssetTransferRightsToken(uint256 atrTokenId) external {
		// Load asset
		MultiToken.Asset memory asset = getAsset(atrTokenId);

		// Check that token is indeed tokenized
		require(asset.assetAddress != address(0), "Asset transfer rights are not tokenized");

		// Check that sender is ATR token owner
		require(ownerOf(atrTokenId) == msg.sender, "Sender is not ATR token owner");

		// Check that ATR token is in the same wallet as tokenized asset
		// @dev Without this condition ATR would not know from which address to remove the ATR token
		require(asset.balanceOf(msg.sender) >= asset.amount, "Sender does not have enough amount of tokenized asset");

		_assets[atrTokenId] = MultiToken.Asset(address(0), MultiToken.Category.ERC20, 0, 0);
		require(_ownedAssetATRIds[msg.sender].remove(atrTokenId), "Tokenized asset is not in the wallet");

		_burn(atrTokenId);
	}


	/*----------------------------------------------------------*|
	|*  # Transfer asset with ATR token                         *|
	|*----------------------------------------------------------*/

	// Transfer assets via ATR token
	// Asset can be transferred only to another PWN Wallet
	// Argument `burnToken` will burn the ATR token and transfer asset to any address (don't have to be PWN Wallet)
	function transferAssetFrom(address from, address to, uint256 atrTokenId, bool burnToken) external {
		// Load asset
		MultiToken.Asset memory asset = getAsset(atrTokenId);

		// Check that transferring to different address
		require(from != to, "Transferring asset to same address");

		// Check that asset transfer rights are tokenized
		require(asset.assetAddress != address(0), "Transfer rights are not tokenized");

		// Check that sender is ATR token owner
		require(ownerOf(atrTokenId) == msg.sender, "Sender is not ATR token owner");

		// Update owned assets by wallet
		require(_ownedAssetATRIds[from].remove(atrTokenId), "Asset is not in target wallet");

		if (burnToken) {
			// Burn the ATR token
			_assets[atrTokenId] = MultiToken.Asset(address(0), MultiToken.Category.ERC20, 0, 0);

			_burn(atrTokenId);
		} else {
			// Fail if recipient is not PWNWallet
			require(walletFactory.isValidWallet(to) == true, "Transfers of asset with tokenized transfer rights are allowed only to PWN Wallets");

			// Update owned assets by wallet
			_ownedAssetATRIds[to].add(atrTokenId);
		}

		IPWNWallet(from).transferAsset(asset, to);
	}


	/*----------------------------------------------------------*|
	|*  # Utility                                               *|
	|*----------------------------------------------------------*/

	function getAsset(uint256 atrTokenId) public view returns (MultiToken.Asset memory) {
		return _assets[atrTokenId];
	}

	function ownedAssetATRIds() public view returns (uint256[] memory) {
		return _ownedAssetATRIds[msg.sender].values();
	}


	/*----------------------------------------------------------*|
	|*  # Private                                               *|
	|*----------------------------------------------------------*/

	function areEqual(MultiToken.Asset memory asset1, MultiToken.Asset memory asset2) private pure returns (bool) {
		return
			asset1.assetAddress == asset2.assetAddress &&
			asset1.category == asset2.category &&
			(asset1.category == MultiToken.Category.ERC20 || asset1.id == asset2.id);
	}

}
