// SPDX-License-Identifier: LGPL-3.0-only
pragma solidity 0.8.15;

import "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC777/IERC777.sol";
import "openzeppelin-contracts/contracts/utils/introspection/IERC1820Registry.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";

import "safe-contracts/base/GuardManager.sol";
import "safe-contracts/common/Enum.sol";

import "../AssetTransferRights.sol";
import "./IAssetTransferRightsGuard.sol";
import "./OperatorsContext.sol";


/**
 * @title Asset Transfer Rights Guard
 * @notice Contract responsible for enforcing asset transfer right rules.
 * @dev Should be used as a Gnosis Safe guard.
 */
contract AssetTransferRightsGuard is Initializable, Guard, IAssetTransferRightsGuard {
	using EnumerableSet for EnumerableSet.AddressSet;


	/*----------------------------------------------------------*|
	|*  # VARIABLES & CONSTANTS DEFINITIONS                     *|
	|*----------------------------------------------------------*/

	string public constant VERSION = "0.1.0";

	address internal constant ERC1820_REGISTRY_ADDRESS = 0x1820a4B7618BdE71Dce8cdc73aAB6C95905faD24;

	AssetTransferRights internal atr;
	OperatorsContext internal operatorsContext;


	/*----------------------------------------------------------*|
	|*  # CONSTRUCTOR                                           *|
	|*----------------------------------------------------------*/

	constructor() {

	}

	/**
	 * @dev Initialize AssetTransferRightsGuard.
	 * @param _atr Address of AssetTransferRights contract, used to check tokenized balances.
	 * @param _operatorContext Address of OperatorsContext, used to manage approved operators per asset collection.
	 */
	function initialize(address _atr, address _operatorContext) external initializer {
		atr = AssetTransferRights(_atr);
		operatorsContext = OperatorsContext(_operatorContext);
	}


	/*----------------------------------------------------------*|
	|*  # GUARD INTERFACE                                       *|
	|*----------------------------------------------------------*/

	/**
	 * @dev Hook that is called before transaction execution.
	 *      This hook is enforcing asset transfer right rules.
	 * @param to Destination address of Safe transaction.
     * @param data Data payload of Safe transaction.
     * @param operation Operation type of Safe transaction.
     * @param safeTxGas Gas that should be used for the Safe transaction.
     * @param gasPrice Gas price that should be used for the payment calculation.
	 */
	function checkTransaction(
		address to,
		uint256 /*value*/,
		bytes calldata data,
		Enum.Operation operation,
		uint256 safeTxGas,
		uint256 /*baseGas*/,
		uint256 gasPrice,
		address /*gasToken*/,
		address payable /*refundReceiver*/,
		bytes memory /*signatures*/,
		address /*msgSender*/ // msgSender is caller on safe, msg.sender is safe
	) external {
		require(safeTxGas == 0, "Safe tx gas has to be 0 for tx to revert in case of failure");
		require(gasPrice == 0, "Gas price has to be 0 for tx to revert in case of failure");
		require(operation == Enum.Operation.Call, "Only call operations are allowed");

		// Self authorization calls
		if (to == msg.sender) {
			_checkManagerUpdates(data);
		}

		// Trust ATR contract
		if (to != address(atr)) {
			_checkExecutionCalls(msg.sender, to, data);
		}
	}

	/**
	 * @dev Hook that is called after transaction execution.
	 *      This hook is checking that tokenized balance is sufficient after transaction execution.
	 * @param success Value if transaction was successful.
	 */
	function checkAfterExecution(bytes32 /*txHash*/, bool success) view external {
		if (success)
			require(atr.hasSufficientTokenizedBalance(msg.sender), "Insufficient tokenized balance");
	}


	/*----------------------------------------------------------*|
	|*  # EXECUTION CHECKS                                      *|
	|*----------------------------------------------------------*/

	function _checkManagerUpdates(bytes calldata data) pure private {
		// Get function selector from data
		bytes4 funcSelector = bytes4(data);

		// GuardManager.setGuard(address)
		if (funcSelector == 0xe19a9dd9) {
			revert("Cannot change ATR guard");
		}

		// ModuleManager.enableModule(address)
		else if (funcSelector == 0x610b5925) {
			revert("Cannot enable ATR module");
		}

		// ModuleManager.disableModule(address,address)
		else if (funcSelector == 0xe009cfde) {
			revert("Cannot disable ATR module");
		}

		// FallbackManager.setFallbackHandler(address)
		else if (funcSelector == 0xf08a0323) {
			revert("Cannot change fallback handler");
		}
	}

	function _checkExecutionCalls(address safeAddress, address target, bytes calldata data) private {
		// Get function selector from data
		bytes4 funcSelector = bytes4(data);

		// ERC20/ERC721 - approve(address,uint256)
		if (funcSelector == 0x095ea7b3) {
			// Block any approve call if there is at least one tokenized asset from a collection
			require(atr.numberOfTokenizedAssetsFromCollection(safeAddress, target) == 0, "Some asset from collection has transfer right token minted");

			(address operator, uint256 amount) = abi.decode(data[4:], (address, uint256));

			// Safe don't need to track approved ERC721 asset ids, because it's possible to get this information from ERC721 contract directly.
			// ERC20 contract doesn't provide possibility to list all addresses that are approved to transfer asset on behalf of an owner.
			// That's why a safe has to track operators.

			_handleERC20Approval(safeAddress, target, operator, amount);
		}

		// ERC20 - increaseAllowance(address,uint256)
		else if (funcSelector == 0x39509351) {
			// Block any increaseAllowance call if there is at least one tokenized asset from a collection
			require(atr.numberOfTokenizedAssetsFromCollection(safeAddress, target) == 0, "Some asset from collection has transfer right token minted");

			(address operator, uint256 amount) = abi.decode(data[4:], (address, uint256));
			if (amount > 0) {
				operatorsContext.add(safeAddress, target, operator);
			}
		}

		// ERC20 - decreaseAllowance(address,uint256)
		else if (funcSelector == 0xa457c2d7) {
			(address operator, uint256 amount) = abi.decode(data[4:], (address, uint256));
			try IERC20(target).allowance(safeAddress, operator) returns (uint256 allowance) {

				if (allowance <= amount) {
					operatorsContext.remove(safeAddress, target, operator);
				}

			} catch {}
		}

		// ERC721/ERC1155 - setApprovalForAll(address,bool)
		else if (funcSelector == 0xa22cb465) {
			// Block any setApprovalForAll call if there is at least one tokenized asset from a collection
			require(atr.numberOfTokenizedAssetsFromCollection(safeAddress, target) == 0, "Some asset from collection has transfer right token minted");

			(address operator, bool approved) = abi.decode(data[4:], (address, bool));

			// Not ERC721 nor ERC1155 does provider direct way how to get list of approved operators.
			// That's why a wallet has to track them.

			if (approved) {
				operatorsContext.add(safeAddress, target, operator);
			} else {
				operatorsContext.remove(safeAddress, target, operator);
			}
		}

		// ERC777 - authorizeOperator(address)
		else if (funcSelector == 0x959b8c3f) {
			// Block any authorizeOperator call if there is at least one tokenized asset from a collection
			require(atr.numberOfTokenizedAssetsFromCollection(safeAddress, target) == 0, "Some asset from collection has transfer right token minted");

			address operator = abi.decode(data[4:], (address));
			operatorsContext.add(safeAddress, target, operator);
		}

		// ERC777 - revokeOperator(address)
		else if (funcSelector == 0xfad8b32a) {
			address operator = abi.decode(data[4:], (address));
			operatorsContext.remove(safeAddress, target, operator);
		}

		// ERC1363 - approveAndCall(address,uint256)
		else if (funcSelector == 0x3177029f) {
			// Block any approveAndCall call if there is at least one tokenized asset from a collection
			require(atr.numberOfTokenizedAssetsFromCollection(safeAddress, target) == 0, "Some asset from collection has transfer right token minted");

			(address operator, uint256 amount) = abi.decode(data[4:], (address, uint256));
			_handleERC20Approval(safeAddress, target, operator, amount);
		}

		// ERC1363 - approveAndCall(address,uint256,bytes)
		else if (funcSelector == 0xcae9ca51) {
			// Block any approveAndCall call if there is at least one tokenized asset from a collection
			require(atr.numberOfTokenizedAssetsFromCollection(safeAddress, target) == 0, "Some asset from collection has transfer right token minted");

			(address operator, uint256 amount,) = abi.decode(data[4:], (address, uint256, bytes));
			_handleERC20Approval(safeAddress, target, operator, amount);
		}
	}

	function _handleERC20Approval(address safeAddress, address target, address operator, uint256 amount) private {
		// This function is also called for ERC721 assets (as they share approve function signature),
		// thus allowance call can throw an error and needs to be called in try / catch block.
		try IERC20(target).allowance(safeAddress, operator) returns (uint256 allowance) {

			if (allowance != 0 && amount == 0)
				operatorsContext.remove(safeAddress, target, operator);

			else if (allowance == 0 && amount != 0)
				operatorsContext.add(safeAddress, target, operator);

		} catch {
			// ERC721 approvals don't have to be tracked as they can be retrieved from an asset contract directly
		}
	}

	/*----------------------------------------------------------*|
	|*  # OPERATOR MANAGER                                      *|
	|*----------------------------------------------------------*/

	/**
	 * @dev See {IAssetTransferRightsGuard-hasOperatorFor}.
	 */
	function hasOperatorFor(address safeAddress, address assetAddress) external view returns (bool) {
		// ERC777 defines `defaultOperators`
		address implementer = IERC1820Registry(ERC1820_REGISTRY_ADDRESS).getInterfaceImplementer(assetAddress, keccak256("ERC777Token"));
        if (implementer == assetAddress) {
        	address[] memory defaultOperators = IERC777(assetAddress).defaultOperators();

        	for (uint256 i; i < defaultOperators.length; ++i)
	            if (IERC777(assetAddress).isOperatorFor(defaultOperators[i], safeAddress))
	            	return true;
        }

		return operatorsContext.hasOperatorFor(safeAddress, assetAddress);
	}

}
