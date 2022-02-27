// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract PWNWallet is Ownable /*ERC721, IERC721Receiver*/ {


	constructor() Ownable() /*ERC721("Transfer Right", "TR")*/ {

	}


	function execute(address target, bytes memory calladata) external payable onlyOwner returns (bytes memory) {
		(bool success, bytes memory output) = target.call{ value: msg.value }(calladata);

		// TODO: Parse error message from output data
		require(success);

		return output;
	}

}
