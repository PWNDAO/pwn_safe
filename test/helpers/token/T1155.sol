// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";


contract T1155 is ERC1155("uri://") {

	bool private _supportingERC165 = true;

	function foo() payable external {

	}

	function mint(address owner, uint256 id, uint256 amount) external {
		_mint(owner, id, amount, "");
	}

	function burn(address owner, uint256 id, uint256 amount) external {
		_burn(owner, id, amount);
	}

	function supportERC165(bool support) external {
		_supportingERC165 = support;
	}

	function supportsInterface(bytes4 interfaceId) public override view returns (bool) {
		return _supportingERC165 && super.supportsInterface(interfaceId);
	}

}
