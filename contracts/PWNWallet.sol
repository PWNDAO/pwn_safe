// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@pwnfinance/multitoken/contracts/MultiToken.sol";
import "./AssetTransferRights.sol";
import "./IPWNWallet.sol";


contract PWNWallet is Ownable, IPWNWallet, IERC721Receiver, IERC1155Receiver, Initializable {
	using EnumerableSet for EnumerableSet.AddressSet;
	using MultiToken for MultiToken.Asset;

	AssetTransferRights internal _atr;

	// Set of operators per asset address
	mapping (address => EnumerableSet.AddressSet) internal _operators;

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
		// Gen function selector from calldata
		bytes4 funcSelector;
		assembly {
			funcSelector := calldataload(data.offset)
		}



		// ERC20/ERC721 - approve
		if (funcSelector == 0x095ea7b3) {
			// Block any approve call if there is at least one tokenized asset from a collection
			require(_atr.ownedFromCollection(target) == 0, "Cannot approve asset while having transfer right token minted");

			(address operator, uint256 amount) = abi.decode(data[4:], (address, uint256));

			// Wallet don't need to track approved ERC721 asset ids, because it's possible to get this information from ERC721 contract directly.
			// ERC20 contract doesn't provide possibility to list all addresses that are approved to transfer asset on behalf of an owner.
			// That's why a wallet has to track operators.

			try IERC20(target).allowance(address(this), operator) returns (uint256 allowance) {

				if (allowance != 0 && amount == 0) {
					_operators[target].remove(operator);
				}

				else if (allowance == 0 && amount != 0) {
					_operators[target].add(operator);
				}

			} catch {}

		}

		// TODO: ERC20-increaseAllowance & decreaseAllowance

		// ERC721/ERC1155 - setApprovalForAll
		else if (funcSelector == 0xa22cb465) {
			// Block any approve for all call if there is at least one tokenized asset from a collection
			require(_atr.ownedFromCollection(target) == 0, "Cannot approve all assets while having transfer right token minted");

			(address operator, bool approved) = abi.decode(data[4:], (address, bool));

			// Not ERC721 nor ERC1155 does provider direct way how to get list of approved operators.
			// That's why a wallet has to track them.

			if (approved) {
				_operators[target].add(operator);
			} else {
				_operators[target].remove(operator);
			}
		}



		// Execute call
		(bool success, bytes memory output) = target.call{ value: msg.value }(data);

		// TODO: Revert with proper revert message
		if (!success) {
			assembly {
				revert(add(output, 32), output)
			}
		}



		// Assert that tokenized asset balances did not change
		uint256[] memory atrs = _atr.ownedAssetATRIds();
		MultiToken.Asset[] memory balances = new MultiToken.Asset[](atrs.length);
		uint256 nextEmptyIndex;
		for (uint256 i = 0; i < atrs.length; ++i) {
			MultiToken.Asset memory asset = _atr.getAsset(atrs[i]);

			// Check that wallet owns at least that amount
			// Need to add fungible token amounts together

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

	function transferAssetFrom(address from, uint256 atrTokenId, bool burnToken) external onlyOwner {
		_atr.transferAssetFrom(from, atrTokenId, burnToken);
	}

	// Can happen when approved address transfers all approved assets.
	// Approved address will stay as operator, even though the allowance would be 0.
	// The transfer would not update wallets internal state.
	function resolveInvalidApproval(address assetAddress, address operator) external {
		uint256 allowance = IERC20(assetAddress).allowance(address(this), operator);
		if (allowance == 0) {
			_operators[assetAddress].remove(operator);
		}
	}


	/*----------------------------------------------------------*|
	|*  # IPWNWallet                                            *|
	|*----------------------------------------------------------*/

	function transferAsset(MultiToken.Asset memory asset, address to) external onlyATRContract {
		asset.transferAsset(to);
	}

	function hasApprovalsFor(address assetAddress) external view returns (bool) {
		return _operators[assetAddress].length() > 0;
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
