// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@pwnfinance/multitoken/contracts/MultiToken.sol";
import "./AssetTransferRights.sol";
import "./PWNWalletFactory.sol";
import "./IPWNWallet.sol";


contract PWNWallet is Ownable, IPWNWallet, IERC721Receiver, IERC1155Receiver, Initializable {
	using EnumerableSet for EnumerableSet.AddressSet;
	using MultiToken for MultiToken.Asset;

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

		// TODO: block other approval functions

		// Execute call
		(bool success, bytes memory output) = target.call{ value: msg.value }(data);

		if (!success) {
			assembly {
				revert(add(output, 32), output)
			}
		}

		// Assert that checks tokenized asset balances
		uint256[] memory atrs = _atr.ownedAssetATRIds();
		MultiToken.Asset[] memory balances = new MultiToken.Asset[](atrs.length);
		uint256 nextEmptyIndex;
		for (uint256 i = 0; i < atrs.length; ++i) {
			MultiToken.Asset memory asset = _atr.getAsset(atrs[i]);

			// Check that wallet owns at least that amount
			// Need to add fungible token amounts together
			// Option 1: use mapping, would need to reset mapping after every call, probably very expensive
			// -> Option 2: store assets in an array and always try to find them

			uint256 assetIndex = _find(balances, asset);
			if (assetIndex == balances.length) {
				assetIndex = nextEmptyIndex++;
				balances[assetIndex] = asset;
			} else {
				balances[assetIndex].amount += asset.amount;
			}

			require(balances[assetIndex].amount <= asset.balanceOf(address(this)), "One of the tokenized asset moved from the wallet");
		}

		return output;
	}


	// ## Wallet utility

	function mintAssetTransferRightsToken(MultiToken.Asset memory asset) external onlyOwner {
		_atr.mintAssetTransferRightsToken(asset);
	}

	function burnAssetTransferRightsToken(uint256 atrTokenId) external onlyOwner {
		_atr.burnAssetTransferRightsToken(atrTokenId);
	}


	/*----------------------------------------------------------*|
	|*  # IPWNWallet                                            *|
	|*----------------------------------------------------------*/

	function transferAsset(MultiToken.Asset memory asset, address to) external onlyATRContract {
		asset.transferAsset(to);
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


	/*----------------------------------------------------------*|
	|*  # IERC1155Receiver                                       *|
	|*----------------------------------------------------------*/

	function onERC1155Received(
		address /*operator*/,
		address /*from*/,
		uint256 /*id*/,
		uint256 /*value*/,
		bytes calldata /*data*/
	) external pure returns (bytes4) {
		return IERC1155Receiver.onERC1155Received.selector;
	}

	function onERC1155BatchReceived(
		address /*operator*/,
		address /*from*/,
		uint256[] calldata /*ids*/,
		uint256[] calldata /*values*/,
		bytes calldata /*data*/
	) external pure returns (bytes4) {
		return IERC1155Receiver.onERC1155BatchReceived.selector;
	}


	/*----------------------------------------------------------*|
	|*  # IERC165                                               *|
	|*----------------------------------------------------------*/

	function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
		return
			interfaceId == type(IPWNWallet).interfaceId ||
			interfaceId == type(IERC721Receiver).interfaceId ||
			interfaceId == type(IERC1155Receiver).interfaceId ||
			interfaceId == type(IERC165).interfaceId;
	}


	/*----------------------------------------------------------*|
	|*  # Private                                               *|
	|*----------------------------------------------------------*/

	function _find(MultiToken.Asset[] memory assets, MultiToken.Asset memory asset) private pure returns (uint256) {
		for (uint256 i = 0; i < assets.length; ++i) {
			if (assets[i].assetAddress == address(0)) {
				break;
			}

			// TODO: Move to MultiToken as `isSameAssetAs`
			// TODO: Implement `isValid` function on MultiToken.Asset to check e.g.
			//		 category == ERC20 -> id == 0
			//		 amount > 0
			if (assets[i].assetAddress == asset.assetAddress && (assets[i].id == asset.id || assets[i].category == MultiToken.Category.ERC20)) {
				return i;
			}
		}

		return assets.length;
	}

}
