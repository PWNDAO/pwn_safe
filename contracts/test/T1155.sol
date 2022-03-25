// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";


contract T1155 is ERC1155("uri://") {

	function foo() external {

	}

	function mint(address owner, uint256 id, uint256 amount) external {
		_mint(owner, id, amount, "");
	}

	function burn(address owner, uint256 id, uint256 amount) external {
		_burn(owner, id, amount);
	}
}
