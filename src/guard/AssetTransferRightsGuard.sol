// SPDX-License-Identifier: UNLICENSED
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

	function initialize(address _atr, address _operatorContext) external initializer {
		atr = AssetTransferRights(_atr);
		operatorsContext = OperatorsContext(_operatorContext);
	}


	/*----------------------------------------------------------*|
	|*  # GUARD INTERFACE                                       *|
	|*----------------------------------------------------------*/

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
			checkManagerUpdates(data);
		}

		// Trust ATR contract
		if (to != address(atr)) {
			checkExecutionCalls(msg.sender, to, data);
		}
	}

	function checkAfterExecution(bytes32 /*txHash*/, bool success) view external {
		if (success)
			require(atr.hasSufficientTokenizedBalance(msg.sender), "Insufficient tokenized balance");
	}


	/*----------------------------------------------------------*|
	|*  # MANAGER UPDATES CHECKS                                *|
	|*----------------------------------------------------------*/

	function checkManagerUpdates(bytes calldata data) pure internal {
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


	/*----------------------------------------------------------*|
	|*  # EXECUTION CHECKS                                      *|
	|*----------------------------------------------------------*/

	function checkExecutionCalls(address safeAddress, address target, bytes calldata data) internal {
		// Get function selector from data
		bytes4 funcSelector = bytes4(data);

		// ERC20/ERC721 - approve
		if (funcSelector == 0x095ea7b3) {
			// Block any approve call if there is at least one tokenized asset from a collection
			require(atr.tokenizedBalanceOf(address(this), target) == 0, "Some asset from collection has transfer right token minted");

			(address operator, uint256 amount) = abi.decode(data[4:], (address, uint256));

			// Wallet don't need to track approved ERC721 asset ids, because it's possible to get this information from ERC721 contract directly.
			// ERC20 contract doesn't provide possibility to list all addresses that are approved to transfer asset on behalf of an owner.
			// That's why a wallet has to track operators.

			_handleERC20Approval(safeAddress, target, operator, amount);
		}

		// ERC20 - increaseAllowance
		else if (funcSelector == 0x39509351) {
			// Block any increaseAllowance call if there is at least one tokenized asset from a collection
			require(atr.tokenizedBalanceOf(address(this), target) == 0, "Some asset from collection has transfer right token minted");

			(address operator, uint256 amount) = abi.decode(data[4:], (address, uint256));

			if (amount > 0) {
				operatorsContext.add(safeAddress, target, operator);
			}
		}

		// ERC20 - decreaseAllowance
		else if (funcSelector == 0xa457c2d7) {
			(address operator, uint256 amount) = abi.decode(data[4:], (address, uint256));

			try IERC20(target).allowance(address(this), operator) returns (uint256 allowance) {

				if (allowance <= amount) {
					operatorsContext.remove(safeAddress, target, operator);
				}

			} catch {}
		}

		// ERC721/ERC1155 - setApprovalForAll
		else if (funcSelector == 0xa22cb465) {
			// Block any setApprovalForAll call if there is at least one tokenized asset from a collection
			require(atr.tokenizedBalanceOf(address(this), target) == 0, "Some asset from collection has transfer right token minted");

			(address operator, bool approved) = abi.decode(data[4:], (address, bool));

			// Not ERC721 nor ERC1155 does provider direct way how to get list of approved operators.
			// That's why a wallet has to track them.

			if (approved) {
				operatorsContext.add(safeAddress, target, operator);
			} else {
				operatorsContext.remove(safeAddress, target, operator);
			}
		}

		// ERC777 - authorizeOperator
		else if (funcSelector == 0x959b8c3f) {
			// Block any authorizeOperator call if there is at least one tokenized asset from a collection
			require(atr.tokenizedBalanceOf(address(this), target) == 0, "Some asset from collection has transfer right token minted");

			address operator = abi.decode(data[4:], (address));

			operatorsContext.add(safeAddress, target, operator);
		}

		// ERC777 - revokeOperator
		else if (funcSelector == 0xfad8b32a) {
			address operator = abi.decode(data[4:], (address));

			operatorsContext.remove(safeAddress, target, operator);
		}

		// ERC1363 - approveAndCall
		else if (funcSelector == 0x3177029f) {
			// Block any approveAndCall call if there is at least one tokenized asset from a collection
			require(atr.tokenizedBalanceOf(address(this), target) == 0, "Some asset from collection has transfer right token minted");

			(address operator, uint256 amount) = abi.decode(data[4:], (address, uint256));

			_handleERC20Approval(safeAddress, target, operator, amount);
		}

		// ERC1363 - approveAndCall(bytes)
		else if (funcSelector == 0xcae9ca51) {
			// Block any approveAndCall call if there is at least one tokenized asset from a collection
			require(atr.tokenizedBalanceOf(address(this), target) == 0, "Some asset from collection has transfer right token minted");

			(address operator, uint256 amount,) = abi.decode(data[4:], (address, uint256, bytes));

			_handleERC20Approval(safeAddress, target, operator, amount);
		}
	}


	/*----------------------------------------------------------*|
	|*  # OPERATOR MANAGER                                      *|
	|*----------------------------------------------------------*/

	function hasOperatorFor(address safeAddress, address assetAddress) external view returns (bool) {
		// ERC777 defines `defaultOperators`
		address implementer = IERC1820Registry(ERC1820_REGISTRY_ADDRESS).getInterfaceImplementer(assetAddress, keccak256("ERC777Token"));
        if (implementer == assetAddress) {
        	address[] memory defaultOperators = IERC777(assetAddress).defaultOperators();

        	for (uint256 i; i < defaultOperators.length; ++i)
	            if (IERC777(assetAddress).isOperatorFor(defaultOperators[i], address(this)))
	            	return true;
        }

		return operatorsContext.hasOperatorFor(safeAddress, assetAddress);
	}


	/*----------------------------------------------------------*|
	|*  # PRIVATE                                               *|
	|*----------------------------------------------------------*/

	function _handleERC20Approval(address safeAddress, address target, address operator, uint256 amount) private {
		try IERC20(target).allowance(address(this), operator) returns (uint256 allowance) {

			if (allowance != 0 && amount == 0) {
				operatorsContext.remove(safeAddress, target, operator);
			}

			else if (allowance == 0 && amount != 0) {
				operatorsContext.add(safeAddress, target, operator);
			}

		} catch {}
	}

}
