// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@pwnfinance/multitoken/contracts/MultiToken.sol";
import "./AssetTransferRights.sol";
import "./IPWNWallet.sol";

/**
 * @title PWN Wallet
 * @author PWN Finance
 * @notice Contract wallet that enforces rules of tokenized asset transfer rights
 * @notice If wallet owner tokenizes transfer rights of its asset, wallet will not enable the owner to trasnfer the asset without the ATR token
 */
contract PWNWallet is Ownable, IPWNWallet, IERC721Receiver, IERC1155Receiver, Initializable {
	using EnumerableSet for EnumerableSet.AddressSet;
	using MultiToken for MultiToken.Asset;


	/*----------------------------------------------------------*|
	|*  # VARIABLES & CONSTANTS DEFINITIONS                     *|
	|*----------------------------------------------------------*/

	/**
	 * @notice Address of AssetTransferRights contract
	 */
	AssetTransferRights internal _atr;

	/**
	 * @notice Set of operators per asset address
	 * @dev Operator is any address that can trasnfer asset on behalf of an owner
	 * @dev Could have allowance (ERC20) or could approval for all owned assets (ERC721/1155-setApprovalForAll)
	 * @dev Operator is not address approved to transfer concrete ERC721 asset. This approvals are not tracked by wallet.
	 */
	mapping (address => EnumerableSet.AddressSet) internal _operators;


	/*----------------------------------------------------------*|
	|*  # EVENTS & ERRORS DEFINITIONS                           *|
	|*----------------------------------------------------------*/

	// No events nor error defined


	/*----------------------------------------------------------*|
	|*  # MODIFIERS                                             *|
	|*----------------------------------------------------------*/

	/**
	 * @dev Throws when called by any other than ATR contract address
	 */
	modifier onlyATRContract() {
		require(msg.sender == address(_atr), "Caller is not asset transfer rights contract");
		_;
	}


	/*----------------------------------------------------------*|
	|*  # CONSTRUCTOR                                           *|
	|*----------------------------------------------------------*/

	constructor() Ownable() {

	}

	/**
	 * @dev Since proxied contracts do not make use of a constructor, it's common to move constructor logic to an
	 * external initializer function, usually called `initialize`.
	 *
	 * @param originalOwner Address of a wallet owner
	 * @param atr Address of AssetTransferRights contract
	 */
	function initialize(address originalOwner, address atr) external initializer {
		_transferOwnership(originalOwner);
		_atr = AssetTransferRights(atr);
	}


	/*----------------------------------------------------------*|
	|*  # PWNWallet                                             *|
	|*----------------------------------------------------------*/

	// ## Wallet execution

	/**
	 * @notice Execute arbitrary calldata on a target address
	 *
	 * @dev This is generic function that takes raw transaction `data` and makes a call with them on a `target` address.
	 * This function is the main function that makes this contract a wallet.
	 * Also it has build in rules, that restricts wallet owner from transferring asset, that has transfer rights tokenized.
	 *
	 * @param target Address of a target contract to call with `data`
	 * @param data Raw transaction calldata to be called on a `target`
	 * @return Any response from a call as bytes
	 */
	function execute(address target, bytes calldata data) external payable onlyOwner returns (bytes memory) {
		// Gen function selector from calldata
		bytes4 funcSelector;
		assembly {
			funcSelector := calldataload(data.offset)
		}



		// ERC20/ERC721 - approve
		if (funcSelector == 0x095ea7b3) {
			// Block any approve call if there is at least one tokenized asset from a collection
			require(_atr.ownedFromCollection(target) == 0, "Some asset from collection has transfer right token minted");

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

		// ERC20 - increaseAllowance
		else if (funcSelector == 0x39509351) {
			// Block any increaseAllowance call if there is at least one tokenized asset from a collection
			require(_atr.ownedFromCollection(target) == 0, "Some asset from collection has transfer right token minted");

			(address operator, uint256 amount) = abi.decode(data[4:], (address, uint256));

			if (amount > 0) {
				_operators[target].add(operator);
			}
		}

		// ERC20 - decreaseAllowance
		else if (funcSelector == 0xa457c2d7) {
			// Block any decreaseAllowance call if there is at least one tokenized asset from a collection
			// (?) Is this check necessary?
			require(_atr.ownedFromCollection(target) == 0, "Some asset from collection has transfer right token minted");

			(address operator, uint256 amount) = abi.decode(data[4:], (address, uint256));

			try IERC20(target).allowance(address(this), operator) returns (uint256 allowance) {

				if (allowance <= amount) {
					_operators[target].remove(operator);
				}

			} catch {}
		}

		// ERC721/ERC1155 - setApprovalForAll
		else if (funcSelector == 0xa22cb465) {
			// Block any setApprovalForAll call if there is at least one tokenized asset from a collection
			require(_atr.ownedFromCollection(target) == 0, "Some asset from collection has transfer right token minted");

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

		if (!success) {
			assembly {
				revert(add(output, 32), output)
			}
		}



		// Assert that tokenized asset balances did not change
		uint256[] memory atrs = _atr.ownedAssetATRIds();
		for (uint256 i = 0; i < atrs.length; ++i) {
			MultiToken.Asset memory asset = _atr.getAsset(atrs[i]);

			uint256 balance = asset.balanceOf(address(this));
			uint256 tokenizedBalance = _atr.tokenizedBalanceOf(asset);
			require(balance >= tokenizedBalance, "One of the tokenized asset moved from the wallet");
		}



		return output;
	}


	// ## Wallet utility

	/**
	 * @dev See {AssetTransferRights-mintAssetTransferRightsToken}
	 *
	 * @param asset Asset struct defined in MultiToken library. See {MultiToken-Asset}
	 */
	function mintAssetTransferRightsToken(MultiToken.Asset memory asset) external onlyOwner {
		_atr.mintAssetTransferRightsToken(asset);
	}

	/**
	 * @dev See {AssetTransferRights-burnAssetTransferRightsToken}
	 *
	 * @param atrTokenId ATR token id which should be burned
	 */
	function burnAssetTransferRightsToken(uint256 atrTokenId) external onlyOwner {
		_atr.burnAssetTransferRightsToken(atrTokenId);
	}

	/**
	 * @dev See {AssetTransferRights-transferAssetFrom}
	 *
	 * @param from PWN Wallet address from which to transfer asset
	 * @param atrTokenId ATR token id which is used for the transfer
	 * @param burnToken Flag to burn ATR token in the same transaction
	 */
	function transferAssetFrom(address from, uint256 atrTokenId, bool burnToken) external onlyOwner {
		_atr.transferAssetFrom(from, atrTokenId, burnToken);
	}

	/**
	 * @notice Utility function that would resolve invalid approval state of an ERC20 asset
	 *
	 * @dev Invalid approval state can happen when approved address transfers all approved assets from a wallet.
	 * Approved address will stay as operator, even though the allowance would be 0.
	 * Transfer outside of wallet would not update wallets internal state.
	 *
	 * @param assetAddress Address of an asset where operator is wrongly stated
	 * @param operator Address of an operator which is wrongly stated
	 */
	function resolveInvalidApproval(address assetAddress, address operator) external {
		uint256 allowance = IERC20(assetAddress).allowance(address(this), operator);
		if (allowance == 0) {
			_operators[assetAddress].remove(operator);
		}
	}


	/*----------------------------------------------------------*|
	|*  # IPWNWallet                                            *|
	|*----------------------------------------------------------*/

	/**
	 * @dev See {IPWNWallet-transferAsset}
	 */
	function transferAsset(MultiToken.Asset memory asset, address to) external onlyATRContract {
		asset.transferAsset(to);
	}

	/**
	 * @dev See {IPWNWallet-hasApprovalsFor}
	 */
	function hasApprovalsFor(address assetAddress) external view returns (bool) {
		return _operators[assetAddress].length() > 0;
	}


	/*----------------------------------------------------------*|
	|*  # IERC721Receiver                                       *|
	|*----------------------------------------------------------*/

	/**
	 * @dev {IERC721Receiver-onERC721Received}
	 */
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

	/**
	 * @dev {IERC1155Receiver-onERC1155Received}
	 */
	function onERC1155Received(
		address /*operator*/,
		address /*from*/,
		uint256 /*id*/,
		uint256 /*value*/,
		bytes calldata /*data*/
	) external pure returns (bytes4) {
		return IERC1155Receiver.onERC1155Received.selector;
	}

	/**
	 * @dev {IERC1155Receiver-onERC1155BatchReceived}
	 */
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

	/**
	 * @dev {IERC165-supportsInterface}
	 */
	function supportsInterface(bytes4 interfaceId) external pure returns (bool) {
		return
			interfaceId == type(IPWNWallet).interfaceId ||
			interfaceId == type(IERC721Receiver).interfaceId ||
			interfaceId == type(IERC1155Receiver).interfaceId ||
			interfaceId == type(IERC165).interfaceId;
	}

}
