// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC721/IERC721Receiver.sol";
import "openzeppelin-contracts/contracts/token/ERC777/IERC777.sol";
import "openzeppelin-contracts/contracts/token/ERC1155/IERC1155Receiver.sol";
import "openzeppelin-contracts/contracts/utils/introspection/IERC165.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import "openzeppelin-contracts/contracts/utils/introspection/IERC1820Registry.sol";
import "MultiToken/MultiToken.sol";
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

	IERC1820Registry internal constant _ERC1820_REGISTRY = IERC1820Registry(0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24);

	/**
	 * @notice Address of AssetTransferRights contract
	 */
	AssetTransferRights internal _atr;

	/**
	 * @notice Set of operators per asset address
	 * @dev Operator is any address that can transfer asset on behalf of an owner
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
		// Get function selector from calldata
		bytes4 funcSelector;
		assembly {
			funcSelector := calldataload(data.offset)
		}



		// ERC20/ERC721 - approve
		if (funcSelector == 0x095ea7b3) {
			// Block any approve call if there is at least one tokenized asset from a collection
			require(_atr.ownedFromCollection(address(this), target) == 0, "Some asset from collection has transfer right token minted");

			(address operator, uint256 amount) = abi.decode(data[4:], (address, uint256));

			// Wallet don't need to track approved ERC721 asset ids, because it's possible to get this information from ERC721 contract directly.
			// ERC20 contract doesn't provide possibility to list all addresses that are approved to transfer asset on behalf of an owner.
			// That's why a wallet has to track operators.

			_handleERC20Approval(target, operator, amount);
		}

		// ERC20 - increaseAllowance
		else if (funcSelector == 0x39509351) {
			// Block any increaseAllowance call if there is at least one tokenized asset from a collection
			require(_atr.ownedFromCollection(address(this), target) == 0, "Some asset from collection has transfer right token minted");

			(address operator, uint256 amount) = abi.decode(data[4:], (address, uint256));

			if (amount > 0) {
				_operators[target].add(operator);
			}
		}

		// ERC20 - decreaseAllowance
		else if (funcSelector == 0xa457c2d7) {
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
			require(_atr.ownedFromCollection(address(this), target) == 0, "Some asset from collection has transfer right token minted");

			(address operator, bool approved) = abi.decode(data[4:], (address, bool));

			// Not ERC721 nor ERC1155 does provider direct way how to get list of approved operators.
			// That's why a wallet has to track them.

			if (approved) {
				_operators[target].add(operator);
			} else {
				_operators[target].remove(operator);
			}
		}

		// ERC777 - authorizeOperator
		else if (funcSelector == 0x959b8c3f) {
			// Block any authorizeOperator call if there is at least one tokenized asset from a collection
			require(_atr.ownedFromCollection(address(this), target) == 0, "Some asset from collection has transfer right token minted");

			address operator = abi.decode(data[4:], (address));

			_operators[target].add(operator);
		}

		// ERC777 - revokeOperator
		else if (funcSelector == 0xfad8b32a) {
			address operator = abi.decode(data[4:], (address));

			_operators[target].remove(operator);
		}

		// ERC1363 - approveAndCall
		else if (funcSelector == 0x3177029f) {
			// Block any approveAndCall call if there is at least one tokenized asset from a collection
			require(_atr.ownedFromCollection(address(this), target) == 0, "Some asset from collection has transfer right token minted");

			(address operator, uint256 amount) = abi.decode(data[4:], (address, uint256));

			_handleERC20Approval(target, operator, amount);
		}

		// ERC1363 - approveAndCall(bytes)
		else if (funcSelector == 0xcae9ca51) {
			// Block any approveAndCall call if there is at least one tokenized asset from a collection
			require(_atr.ownedFromCollection(address(this), target) == 0, "Some asset from collection has transfer right token minted");

			(address operator, uint256 amount,) = abi.decode(data[4:], (address, uint256, bytes));

			_handleERC20Approval(target, operator, amount);
		}



		// Execute call
		(bool success, bytes memory output) = target.call{ value: msg.value }(data);

		if (!success) {
			assembly {
				revert(add(output, 32), output)
			}
		}



		// Assert that tokenized asset balances did not change
		_atr.checkTokenizedBalance(address(this));



		return output;
	}


	// ## Wallet utility

	/**
	 * @dev See {AssetTransferRights-mintAssetTransferRightsToken}
	 *
	 * @param asset Asset struct defined in MultiToken library. See {MultiToken-Asset}
	 */
	function mintAssetTransferRightsToken(MultiToken.Asset memory asset) external onlyOwner returns (uint256) {
		return _atr.mintAssetTransferRightsToken(asset);
	}

	/**
	 * @dev See {AssetTransferRights-mintAssetTransferRightsTokenBatch}
	 *
	 * @param assets Asset struct list defined in MultiToken library. See {MultiToken-Asset}
	 */
	function mintAssetTransferRightsTokenBatch(MultiToken.Asset[] memory assets) external onlyOwner {
		_atr.mintAssetTransferRightsTokenBatch(assets);
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
	 * @dev See {AssetTransferRights-burnAssetTransferRightsTokenBatch}
	 *
	 * @param atrTokenIds ATR token id list which should be burned
	 */
	function burnAssetTransferRightsTokenBatch(uint256[] calldata atrTokenIds) external onlyOwner {
		_atr.burnAssetTransferRightsTokenBatch(atrTokenIds);
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
	 * @notice Utility function for transferring ATR token
	 *
	 * @dev ATR contract is trusted and ATR token itself cannot tokenize its transfer rights
	 * Thus there is no need to check tokenized balance while transferring ATR token
	 * User can safe gas by transferring ATR token via this function instead of general `execute` function
	 *
	 * @param from Address of current ATR token owner
	 * @param to Address of recipient
	 * @param atrTokenId ATR token id to transfer
	 */
	function transferAtrTokenFrom(address from, address to, uint256 atrTokenId) external onlyOwner {
		_atr.transferFrom(from, to, atrTokenId);
	}

	/**
	 * @notice Utility function for transferring ATR token
	 *
	 * @dev ATR contract is trusted and ATR token itself cannot tokenize its transfer rights
	 * Thus there is no need to check tokenized balance while transferring ATR token
	 * User can safe gas by transferring ATR token via this function instead of general `execute` function
	 *
	 * @param from Address of current ATR token owner
	 * @param to Address of recipient
	 * @param atrTokenId ATR token id to transfer
	 */
	function safeTransferAtrTokenFrom(address from, address to, uint256 atrTokenId) external onlyOwner {
		_atr.safeTransferFrom(from, to, atrTokenId);
	}

	/**
	 * @notice Utility function for transferring ATR token
	 *
	 * @dev ATR contract is trusted and ATR token itself cannot tokenize its transfer rights
	 * Thus there is no need to check tokenized balance while transferring ATR token
	 * User can safe gas by transferring ATR token via this function instead of general `execute` function
	 *
	 * @param from Address of current ATR token owner
	 * @param to Address of recipient
	 * @param atrTokenId ATR token id to transfer
	 * @param data Additional data passet into `onERC721Received` handle with no specific format
	 */
	function safeTransferAtrTokenFrom(address from, address to, uint256 atrTokenId, bytes calldata data) external onlyOwner {
		_atr.safeTransferFrom(from, to, atrTokenId, data);
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

	/**
	 * @notice Utility function for recovering wallets invalid tokenized balance
	 *
	 * @param atrTokenId ATR token id representing underyling asset in question
	 */
	function recoverInvalidTokenizedBalance(uint256 atrTokenId) external {
		_atr.recoverInvalidTokenizedBalance(atrTokenId);
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
		// ERC777 defines `defaultOperators`
		address implementer = _ERC1820_REGISTRY.getInterfaceImplementer(assetAddress, keccak256("ERC777Token"));
        if (implementer == assetAddress) {
        	address[] memory defaultOperators = IERC777(assetAddress).defaultOperators();

        	for (uint256 i; i < defaultOperators.length; ++i)
	            if (IERC777(assetAddress).isOperatorFor(defaultOperators[i], address(this)))
	            	return true;
        }

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


	/*----------------------------------------------------------*|
	|*  # PRIVATE                                               *|
	|*----------------------------------------------------------*/

	function _handleERC20Approval(address target, address operator, uint256 amount) private {
		try IERC20(target).allowance(address(this), operator) returns (uint256 allowance) {

			if (allowance != 0 && amount == 0) {
				_operators[target].remove(operator);
			}

			else if (allowance == 0 && amount != 0) {
				_operators[target].add(operator);
			}

		} catch {}
	}

}
