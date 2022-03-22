// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "./AssetTransferRights.sol";
import "./PWNWalletFactory.sol";
import "./IPWNWallet.sol";

contract PWNWallet is Ownable, IPWNWallet, IERC721Receiver, Initializable {
	using EnumerableSet for EnumerableSet.AddressSet;

	AssetTransferRights internal _atr;

	modifier onlyATRContract() {
		require(msg.sender == address(_atr), "Sender is not asset transfer rights contract");
		_;
	}

	constructor() Ownable() {

	}

	function initialize(address originalOwner, address atr) external initializer {
		_transferOwnership(originalOwner);
		_atr = AssetTransferRights(atr);
	}


	/*----------------------------------------------------------*|
	|*  # PWNWallet                                             *|
	|*----------------------------------------------------------*/

	// ## Wallet execution

	function execute(address target, bytes calldata data) external payable onlyOwner returns (bytes memory) {
		bytes4 funcSelector;
		assembly {
			funcSelector := calldataload(data.offset)
		}

		// ERC721-setApprovalForAll
		if (funcSelector == 0xa22cb465) {
			revert("Cannot set approval for all assets");
		}

		// ERC721-approve
		else if (funcSelector == 0x095ea7b3) {
			revert("Cannot approve asset");
		}

		// Execute call
		(bool success, bytes memory output) = target.call{ value: msg.value }(data);

		if (!success) {
			assembly {
				revert(add(output, 32), output)
			}
		}

		// Assert that checks tokenized asset balances
		uint256[] memory atrs = _atr.ownedAssetATRIds();
		for (uint256 i = 0; i < atrs.length; ++i) {
			(address tokenAddress, uint256 tokenId) = _atr.getToken(atrs[i]);
			require(IERC721(tokenAddress).ownerOf(tokenId) == address(this), "One of the tokenized assets moved from the wallet");
		}

		return output;
	}


	// ## Wallet utility

	function mintAssetTransferRightsToken(address tokenAddress, uint256 tokenId) external onlyOwner {
		_atr.mintAssetTransferRightsToken(tokenAddress, tokenId);
	}

	function burnAssetTransferRightsToken(uint256 atrTokenId) external onlyOwner {
		_atr.burnAssetTransferRightsToken(atrTokenId);
	}


	// ## Transfer asset with ATR token

	function transferAsset(address to, address tokenAddress, uint256 tokenId) external onlyATRContract {
		IERC721(tokenAddress).transferFrom(address(this), to, tokenId);
	}

	// Not tested
	function safeTransferAsset(address to, address tokenAddress, uint256 tokenId) external onlyATRContract {
		IERC721(tokenAddress).safeTransferFrom(address(this), to, tokenId);
	}

	// Not tested
	function safeTransferAsset(address to, address tokenAddress, uint256 tokenId, bytes calldata data) external onlyATRContract {
		IERC721(tokenAddress).safeTransferFrom(address(this), to, tokenId, data);
	}


	/*----------------------------------------------------------*|
	|*  # IPWNWallet                                            *|
	|*----------------------------------------------------------*/


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
