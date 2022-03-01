// SPDX-License-Identifier: None
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "hardhat/console.sol";

contract PWNWallet is Ownable, ERC721, IERC721Receiver {
	using EnumerableSet for EnumerableSet.AddressSet;

	uint256 internal lastTokenId;

	mapping (address => EnumerableSet.AddressSet) internal _operators;
	// Number of TR tokens for asset contract
	mapping (address => uint256) internal _balanceFor;
	mapping (uint256 => Token) internal _tokens;
	mapping (address => mapping (uint256 => bool)) internal _isTokenised;

	struct Token {
		address tokenAddress;
		uint256 tokenId;
	}


	constructor() Ownable() ERC721("Transfer Right", "TR") {

	}


	/*----------------------------------------------------------*|
	|*  # PWNWallet                                             *|
	|*----------------------------------------------------------*/

	// ## Wallet execution

	function execute(address target, bytes calldata data) external payable onlyOwner returns (bytes memory) {
		// If assets implements EIP???? (new EIP for this type) skip all the approve checks
		// else ->

		bytes4 funcSelector;
		assembly {
			funcSelector := calldataload(data.offset)
		}

		// setApproveForAll
		if (funcSelector == 0xa22cb465) {
			require(_balanceFor[target] == 0, "Cannot approve all while having transfer right token minted");

			(address operator, bool approved) = abi.decode(data[4:], (address, bool));

			if (approved) {
				_operators[target].add(operator);
			} else {
				_operators[target].remove(operator);
			}
		}

		// approve
		else if (funcSelector == 0x095ea7b3) {
			(, uint256 tokenId) = abi.decode(data[4:], (address, uint256));

			require(_isTokenised[target][tokenId] == false, "Cannot approve token while having transfer right token minted");
		}

		// transferFrom
		else if (funcSelector == 0x23b872dd) {

		}

		// safeTransferFrom
		else if (funcSelector == 0x42842e0e) {

		}

		// safeTransferFrom with data
		else if (funcSelector == 0xb88d4fde) {

		}


		// TODO: Restrict transferring assets without TR tokens

		// Execute call

		(bool success, bytes memory output) = target.call{ value: msg.value }(data);

		// TODO: Parse error message from output data
		require(success);

		return output;
	}


	// ## Transfer rights

	function mintTransferRightToken(address tokenAddress, uint256 tokenId) external onlyOwner {
		require(_isTokenised[tokenAddress][tokenId] == false, "Token transfer rights are already tokenised");
		require(IERC721(tokenAddress).ownerOf(tokenId) == address(this), "Token is not in wallet");

		// _Other option:_ Remove approve in the transaction instead of throwing error
		require(IERC721(tokenAddress).getApproved(tokenId) == address(0), "Token must not be approved to other address");

		// _Other option:_ Remove all operators in the transaction instead of throwing error
		require(_operators[tokenAddress].length() == 0, "Token collection must not have any operator set");

		uint256 trId = ++lastTokenId;

		_isTokenised[tokenAddress][tokenId] = true;
		_tokens[trId] = Token(tokenAddress, tokenId);
		_balanceFor[tokenAddress] += 1;

		_mint(address(this), trId);
	}

	// Wallet owner can burn the token if the token is in the wallet
	// _Other option:_ Token owner can burn the token anytime
	function burnTransferRightToken(uint256 trId) external onlyOwner {
		Token memory token = _tokens[trId];

		require(_isTokenised[token.tokenAddress][token.tokenId] == true, "Token transfer rights are not tokenised");
		require(ownerOf(trId) == address(this), "Token transfer rights has to be in wallet");

		_isTokenised[token.tokenAddress][token.tokenId] = false;
		_balanceFor[token.tokenAddress] -= 1;

		_burn(trId);
	}


	// ## Wallet utility

	// Remove all operators
	function removeApprovalForAll(address tokenAddress) external onlyOwner {
		EnumerableSet.AddressSet storage operators = _operators[tokenAddress];

		for (uint256 i = 0; i < operators.length(); ++i) {
			IERC721(tokenAddress).setApprovalForAll(operators.at(i), false);
		}
	}


	/*----------------------------------------------------------*|
	|*  # IERC721Receiver                                       *|
	|*----------------------------------------------------------*/

	function onERC721Received(
		address /*operator*/,
		address /*from*/,
		uint256 /*tokenId*/,
		bytes calldata /*data*/
	) external pure returns (bytes4) {
		return IERC721Receiver.onERC721Received.selector;
	}

}
