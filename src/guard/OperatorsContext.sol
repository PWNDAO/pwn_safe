// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.15;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";


/// TODO: Doc
contract OperatorsContext {
	using EnumerableSet for EnumerableSet.AddressSet;


	/*----------------------------------------------------------*|
	|*  # VARIABLES & CONSTANTS DEFINITIONS                     *|
	|*----------------------------------------------------------*/

	/// TODO: Doc
	address internal guard;

	/**
	 * @notice Set of operators per asset address per wallet
	 * @dev Operator is any address that can transfer asset on behalf of an owner
	 *      Could have allowance (ERC20) or could approval for all owned assets (ERC721/1155-setApprovalForAll)
	 *      Operator is not address approved to transfer concrete ERC721 asset. This approvals are not tracked by wallet.
	 *      safe address => collection address => set of operators
	 */
	mapping (address => mapping (address => EnumerableSet.AddressSet)) internal operators;


	/*----------------------------------------------------------*|
	|*  # MODIFIERS                                             *|
	|*----------------------------------------------------------*/

	modifier onlyGuard() {
		require(msg.sender == guard, "Sender is not guard address");
		_;
	}


	/*----------------------------------------------------------*|
	|*  # CONSTRUCTOR                                           *|
	|*----------------------------------------------------------*/

	constructor(address _guard) {
		guard = _guard;
	}


	/*----------------------------------------------------------*|
	|*  # SETTERS                                               *|
	|*----------------------------------------------------------*/

	/// TODO: Doc
	function add(address safe, address asset, address operator) external onlyGuard {
		operators[safe][asset].add(operator);
	}

	/// TODO: Doc
	function remove(address safe, address asset, address operator) external onlyGuard {
		operators[safe][asset].remove(operator);
	}


	/*----------------------------------------------------------*|
	|*  # GETTERS                                               *|
	|*----------------------------------------------------------*/

	/// TODO: Doc
	function hasOperatorFor(address safe, address asset) external view returns (bool) {
		return operators[safe][asset].length() > 0;
	}


	/*----------------------------------------------------------*|
	|*  # RECOVER                                               *|
	|*----------------------------------------------------------*/

	/// TODO: Doc
	function resolveInvalidAllowance(address safe, address asset, address operator) external {
		uint256 allowance = IERC20(asset).allowance(safe, operator);
		if (allowance == 0) {
			operators[safe][asset].remove(operator);
		}
	}

}
