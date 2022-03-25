// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";


contract T721 is ERC721("ERC721", "ERC721") {

	function foo() external {

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

}
