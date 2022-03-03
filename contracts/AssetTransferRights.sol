// SPDX-License-Identifier: None
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "./IPWNWallet.sol";

contract AssetTransferRights is ERC721 {

	uint256 internal lastTokenId;

	mapping (uint256 => Token) internal _tokens;
	mapping (address => mapping (uint256 => bool)) internal _isTokenized;

	// TODO: Rename to `Asset`
	struct Token {
		address tokenAddress;
		uint256 tokenId;
	}


	constructor() ERC721("Asset Transfer Rights", "ATR") {

	}


	/*----------------------------------------------------------*|
	|*  # Transfer rights                                       *|
	|*----------------------------------------------------------*/

	function mintTransferRightToken(address tokenAddress, uint256 tokenId) external returns (uint256) {
		// TODO: check that msg.sender is PWNWallet
		IPWNWallet wallet = IPWNWallet(msg.sender);

		// Check that asset is not tokenized yet
		require(_isTokenized[tokenAddress][tokenId] == false, "Token transfer rights are already tokenised");

		// Check that sender is asset owner
		require(IERC721(tokenAddress).ownerOf(tokenId) == msg.sender, "Token is not in wallet");

		// Check that asset doesn't have approved address
		require(IERC721(tokenAddress).getApproved(tokenId) == address(0), "Token must not be approved to other address");

		// Check that asset doesn't have  operator
		require(wallet.hasOperatorsFor(tokenAddress) == false, "Token collection must not have any operator set");

		uint256 atrTokenId = ++lastTokenId;

		_isTokenized[tokenAddress][tokenId] = true;
		_tokens[atrTokenId] = Token(tokenAddress, tokenId);

		_mint(msg.sender, atrTokenId);

		// TODO: Event

		return atrTokenId;
	}

	// Token owner can burn the token if it's in the same wallet as tokenized asset
	function burnTransferRightToken(uint256 atrTokenId) external {
		// TODO: check that msg.sender is PWNWallet -> if not, tokenized asset balances will not match

		(address tokenAddress, uint256 tokenId) = getToken(atrTokenId);

		// Check that token is indeed tokenized
		require(_isTokenized[tokenAddress][tokenId] == true, "Token transfer rights are not tokenised");

		// Check that sender is ATR token owner
		require(ownerOf(atrTokenId) == msg.sender, "Token transfer rights has to be in wallet");

		// Check that ATR token is in the same wallet as tokenized asset
		// @dev Without this condition ATR would not know from which address to deduct balance of ATR tokens
		require(IERC721(tokenAddress).ownerOf(tokenId) == msg.sender, "ATR token has to be in the same wallet as tokenized asset");

		_isTokenized[tokenAddress][tokenId] = false;
		_tokens[atrTokenId] = Token(address(0), 0);

		_burn(atrTokenId);

		// TODO: Event
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

}
