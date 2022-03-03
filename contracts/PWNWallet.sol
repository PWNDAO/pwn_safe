// SPDX-License-Identifier: None
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./AssetTransferRights.sol";

contract PWNWallet is Ownable, IPWNWallet, IERC721Receiver {
	using EnumerableSet for EnumerableSet.AddressSet;
	using EnumerableSet for EnumerableSet.UintSet;

	AssetTransferRights internal _atr;
	// Number of tokenized assets in wallet
	mapping (address => uint256) internal _balanceFor;
	EnumerableSet.UintSet internal _atrs;
	mapping (address => EnumerableSet.AddressSet) internal _operators;


	constructor(address atr) Ownable() {
		_atr = AssetTransferRights(atr);
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

			require(_atr.isTokenized(target, tokenId) == false, "Cannot approve token while having transfer right token minted");
		}

		// Execute call
		(bool success, bytes memory output) = target.call{ value: msg.value }(data);

		// TODO: Parse error message from output data
		require(success);

		// TODO: Assert that checks tokenized asset balances
		// How to know which assets should not change balance?
		// -> a) store asset as tokenized in wallet?
		// b) store asset owner in ATR contract?
		for (uint256 i = 0; i < _atrs.length(); ++i) {
			(address tokenAddress, uint256 tokenId) = _atr.getToken(_atrs.at(i));
			require(IERC721(tokenAddress).ownerOf(tokenId) == address(this), "One of the tokenized assets moved from the wallet");
		}


		return output;
	}


	// ## Wallet utility

	// Remove all operators
	function removeApprovalForAll(address tokenAddress) external onlyOwner {
		EnumerableSet.AddressSet storage operators = _operators[tokenAddress];

		for (uint256 i = 0; i < operators.length(); ++i) {
			IERC721(tokenAddress).setApprovalForAll(operators.at(i), false);
		}
	}


	// ## ATR token

	function mintTransferRightToken(address tokenAddress, uint256 tokenId) external {
		_balanceFor[tokenAddress] += 1;
		uint256 atrTokenId = _atr.mintTransferRightToken(tokenAddress, tokenId);
		_atrs.add(atrTokenId);
	}

	function burnTransferRightToken(uint256 atrTokenId) public {
		(address tokenAddress, ) = _atr.getToken(atrTokenId);
		_balanceFor[tokenAddress] -= 1;
		_atrs.remove(atrTokenId);
		_atr.burnTransferRightToken(atrTokenId);
	}


	// ## Transfer asset with ATR token

	function transferTokenFrom(address from, address to, uint256 atrTokenId, bool burn) external {
		(address tokenAddress, uint256 tokenId) = _processTransfer(to, atrTokenId, burn);

		if (burn) {
			burnTransferRightToken(atrTokenId);
		}

		IERC721(tokenAddress).transferFrom(from, to, tokenId);

		_afterTransfer();
	}

	function safeTransferTokenFrom(address from, address to, uint256 atrTokenId, bool burn) external {
		(address tokenAddress, uint256 tokenId) = _processTransfer(to, atrTokenId, burn);

		if (burn) {
			burnTransferRightToken(atrTokenId);
		}

		IERC721(tokenAddress).safeTransferFrom(from, to, tokenId);

		_afterTransfer();
	}

	function safeTransferTokenFrom(address from, address to, uint256 atrTokenId, bool burn, bytes calldata data) external {
		(address tokenAddress, uint256 tokenId) = _processTransfer(to, atrTokenId, burn);

		if (burn) {
			burnTransferRightToken(atrTokenId);
		}

		IERC721(tokenAddress).safeTransferFrom(from, to, tokenId, data);

		_afterTransfer();
	}

	function _processTransfer(address to, uint256 atrTokenId, bool burn) internal returns (address tokenAddress, uint256 tokenId) {
		(tokenAddress, tokenId) = _atr.getToken(atrTokenId);

		// Check that asset transfer rights are tokenized
		require(tokenAddress != address(0), "Transfer rights are not tokenized");

		// Check that sender is ATR token owner
		require(_atr.ownerOf(atrTokenId) == msg.sender, "Sender is not ATR token owner");

		if (!burn) {
			// TODO: Fail if recipient is not PWNWallet

			// Check that recipient doesn't have operator for the token collection
			require(IPWNWallet(to).hasOperatorsFor(tokenAddress) == false, "Receiver cannot have operator set for the token");

			IPWNWallet(to).receivedTokenizedAsset(tokenAddress, atrTokenId);
		}

		_balanceFor[tokenAddress] -= 1;
		_atrs.remove(atrTokenId);
	}

	function _afterTransfer() internal {
		// (?) TODO: assert that receiver doesn't have approval on token (in case ERC721 transfer did not reset approvals)
	}


	/*----------------------------------------------------------*|
	|*  # IPWNWallet                                            *|
	|*----------------------------------------------------------*/

	function hasOperatorsFor(address tokenAddress) override external view returns (bool) {
		return _operators[tokenAddress].length() > 0;
	}

	function receivedTokenizedAsset(address tokenAddress, uint256 atrTokenId) external {
		_atrs.add(atrTokenId);
		_balanceFor[tokenAddress] += 1;
	}


	/*----------------------------------------------------------*|
	|*  # IERC721Receiver                                       *|
	|*----------------------------------------------------------*/

	// (?) How to prevent from calling by malicious actor
	function onERC721Received(
		address /*operator*/,
		address /*from*/,
		uint256 /*tokenId*/,
		bytes calldata /*data*/
	) external pure returns (bytes4) {
		return IERC721Receiver.onERC721Received.selector;
	}

}
