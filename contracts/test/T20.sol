// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";


contract T20 is ERC20("ERC20", "ERC20") {

	function foo() external {

	}

	function mint(address owner, uint256 amount) external {
		_mint(owner, amount);
	}

	function burn(address owner, uint256 amount) external {
		_burn(owner, amount);
	}

}
