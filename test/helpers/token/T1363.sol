// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";


/**
 * This is incomplete implementation of ERC1363 token, which exists only for test purposes of PWN Wallet
 */

contract T1363 is ERC165, ERC20("ERC1363", "ERC1363") {

	function foo() payable external {

	}

	function mint(address owner, uint256 amount) external {
		_mint(owner, amount);
	}

	function burn(address owner, uint256 amount) external {
		_burn(owner, amount);
	}

	function supportsInterface(bytes4 interfaceId) public override view returns (bool) {
		return
			super.supportsInterface(interfaceId) ||
			// Should implement IERC1363
			interfaceId == type(IERC20).interfaceId;
	}


	// ERC1363

	function approveAndCall(address spender, uint256 value) external returns (bool) {
		return approve(spender, value);
	}

	function approveAndCall(address spender, uint256 value, bytes memory /*data*/) external returns (bool) {
		return approve(spender, value);
	}

}
