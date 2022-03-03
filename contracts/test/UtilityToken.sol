// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

contract UtilityToken is ERC721 {

	bytes public encodedReturnValue;

	modifier onlyOwner(uint256 tokenId) {
		require(ownerOf(tokenId) == msg.sender, "Not token owner");
		_;
	}

	constructor() ERC721("Utility token", "UTIL") {

	}


	function utilityEmpty() external {
		encodedReturnValue = abi.encode(keccak256("success"));
	}

	function utilityParams(uint256 tokenId, address arg2, string memory arg3) external onlyOwner(tokenId) {
		encodedReturnValue = abi.encode(tokenId, arg2, arg3);
	}

	function utilityEth(uint256 tokenId) external payable onlyOwner(tokenId) {
		encodedReturnValue = abi.encode(tokenId, msg.value);
	}

	receive() external payable {
		encodedReturnValue = abi.encode(msg.value);
	}


	function mint(address owner, uint256 tokenId) external {
		_mint(owner, tokenId);
	}

	function burn(uint256 tokenId) external {
		_burn(tokenId);
	}

}
