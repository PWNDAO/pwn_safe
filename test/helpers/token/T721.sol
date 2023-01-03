// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/token/ERC721/ERC721.sol";


contract T721 is ERC721("ERC721", "ERC721") {

	bool private _supportingERC165 = true;

	function foo() payable external {

	}

	function mint(address owner, uint256 tokenId) external {
		_mint(owner, tokenId);
	}

	function burn(uint256 tokenId) external {
		_burn(tokenId);
	}


	function forceTransfer(address from, address to, uint256 tokenId) external {
		_approve(address(this), tokenId);

		this.transferFrom(from, to, tokenId);
	}

	function revertWithMessage() external pure {
		revert("50m3 6u5t0m err0r m3ssag3");
	}


	function supportERC165(bool support) external {
		_supportingERC165 = support;
	}

	function supportsInterface(bytes4 interfaceId) public override view returns (bool) {
		return _supportingERC165 && super.supportsInterface(interfaceId);
	}

}
