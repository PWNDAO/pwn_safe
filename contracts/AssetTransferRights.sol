// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./IPWNWallet.sol";
import "./PWNWalletFactory.sol";

contract AssetTransferRights is ERC721 {
	using EnumerableSet for EnumerableSet.UintSet;

	uint256 public lastTokenId;
	PWNWalletFactory public walletFactory;

	// Mapping of ATR token id to tokenized asset struct
	// (ATR token id => Token)
	mapping (uint256 => Token) internal _tokens;

	// Mapping if asset is tokenized
	// (tokenAddress => tokenId => isTokenized)
	mapping (address => mapping (uint256 => bool)) internal _isTokenized;

	// Mapping of address to set of ATR ids, that belongs to assets in the addresses pwn wallet
	// The ATR token itself doesn't have to be in the wallet
	// Used in PWNWallet to enumerate over all tokenized assets after arbitrary execution
	// (owner => set of ATR token ids representing tokenized assets currently in owners wallet)
	mapping (address => EnumerableSet.UintSet) internal _ownedAssetATRIds;

	// Number of tokenized assets from collection in wallet
	// Used in PWNWallet to check if owner can setApprovalForAll on given collection
	// (owner => tokenAddress => number of tokenized assets from given collection currently in owners wallet)
	mapping (address => mapping (address => uint256)) internal _ownedFromCollection;

	// TODO: Rename to `Asset`
	struct Token {
		address tokenAddress;
		uint256 tokenId;
	}


	constructor() ERC721("Asset Transfer Rights", "ATR") {
		walletFactory = new PWNWalletFactory(address(this));
	}


	/*----------------------------------------------------------*|
	|*  # Transfer rights                                       *|
	|*----------------------------------------------------------*/

	function mintAssetTransferRightsToken(address tokenAddress, uint256 tokenId) external {
		// Check that token address is not zero address
		require(tokenAddress != address(0), "Cannot tokenize zero address asset");

		// Check that msg.sender is PWNWallet
		require(walletFactory.isValidWallet(msg.sender) == true, "Mint is permitted only from PWN Wallet");

		// Check that asset is not tokenized yet
		require(_isTokenized[tokenAddress][tokenId] == false, "Token transfer rights are already tokenised");

		// Check that sender is asset owner
		require(IERC721(tokenAddress).ownerOf(tokenId) == msg.sender, "Token is not in wallet");

		// Check that asset doesn't have approved address
		require(IERC721(tokenAddress).getApproved(tokenId) == address(0), "Token must not be approved to other address");

		// Check that asset doesn't have  operator
		require(IPWNWallet(msg.sender).hasOperatorsFor(tokenAddress) == false, "Token collection must not have any operator set");

		uint256 atrTokenId = ++lastTokenId;

		_isTokenized[tokenAddress][tokenId] = true;
		_tokens[atrTokenId] = Token(tokenAddress, tokenId);
		_ownedAssetATRIds[msg.sender].add(atrTokenId);
		_ownedFromCollection[msg.sender][tokenAddress] += 1;

		_mint(msg.sender, atrTokenId);

		// TODO: Event
	}

	// Token owner can burn the token if it's in the same wallet as tokenized asset
	function burnAssetTransferRightsToken(uint256 atrTokenId) external {
		(address tokenAddress, uint256 tokenId) = getToken(atrTokenId);

		// Check that token is indeed tokenized
		require(tokenAddress != address(0), "Token transfer rights are not tokenised");

		// Check that sender is ATR token owner
		require(ownerOf(atrTokenId) == msg.sender, "Sender is not ATR token owner");

		// Check that ATR token is in the same wallet as tokenized asset
		// @dev Without this condition ATR would not know from which address to deduct balance of ATR tokens
		require(IERC721(tokenAddress).ownerOf(tokenId) == msg.sender, "Sender is not tokenized asset owner");

		_isTokenized[tokenAddress][tokenId] = false;
		_tokens[atrTokenId] = Token(address(0), 0);
		require(_ownedAssetATRIds[msg.sender].remove(atrTokenId), "Tokenized asset is not in the wallet");
		_ownedFromCollection[msg.sender][tokenAddress] -= 1;

		_burn(atrTokenId);

		// TODO: Event
	}


	/*----------------------------------------------------------*|
	|*  # Transfer asset with ATR token                         *|
	|*----------------------------------------------------------*/

	// Can transfer only from wallet that is calling the transfer
	function transferAssetFrom(address from, address to, uint256 atrTokenId) external {
		(address tokenAddress, uint256 tokenId) = _processTransfer(from, to, atrTokenId);

		IPWNWallet(from).transferAsset(to, tokenAddress, tokenId);
	}

	// Not tested
	function safeTransferAssetFrom(address from, address to, uint256 atrTokenId) external {
		(address tokenAddress, uint256 tokenId) = _processTransfer(from, to, atrTokenId);

		IPWNWallet(from).safeTransferAsset(to, tokenAddress, tokenId);
	}

	// Not tested
	function safeTransferAssetFrom(address from, address to, uint256 atrTokenId, bytes calldata data) external {
		(address tokenAddress, uint256 tokenId) = _processTransfer(from, to, atrTokenId);

		IPWNWallet(from).safeTransferAsset(to, tokenAddress, tokenId, data);
	}

	function _processTransfer(address from, address to, uint256 atrTokenId) internal returns (address tokenAddress, uint256 tokenId) {
		(tokenAddress, tokenId) = getToken(atrTokenId);

		// Check that asset transfer rights are tokenized
		require(tokenAddress != address(0), "Transfer rights are not tokenized");

		// Check that sender is ATR token owner
		require(ownerOf(atrTokenId) == msg.sender, "Sender is not ATR token owner");

		// Fail if recipient is not PWNWallet
		require(walletFactory.isValidWallet(to) == true, "Transfers of asset with tokenized transfer rights are allowed only to PWN Wallets");

		// Check that recipient doesn't have operator for the token collection
		require(IPWNWallet(to).hasOperatorsFor(tokenAddress) == false, "Receiver cannot have operator set for the token");

		// Update owned assets by wallet
		require(_ownedAssetATRIds[from].remove(atrTokenId), "Asset is not in target wallet");
		_ownedAssetATRIds[to].add(atrTokenId);

		// Update owned collections by wallet
		_ownedFromCollection[from][tokenAddress] -= 1;
		_ownedFromCollection[to][tokenAddress] += 1;
	}


	/*----------------------------------------------------------*|
	|*  # Utility                                               *|
	|*----------------------------------------------------------*/

	function getToken(uint256 atrTokenId) public view returns (address tokenAddress, uint256 tokenId) {
		Token memory token = _tokens[atrTokenId];

		tokenAddress = token.tokenAddress;
		tokenId = token.tokenId;
	}

	function isTokenized(address tokenAddress, uint256 tokenId) external view returns (bool) {
		return _isTokenized[tokenAddress][tokenId];
	}

	function ownedAssetATRIds() external view returns (uint256[] memory) {
		return _ownedAssetATRIds[msg.sender].values();
	}

	function ownedFromCollection(address tokenAddress) external view returns (uint256) {
		return _ownedFromCollection[msg.sender][tokenAddress];
	}

}
