const { ethers } = require("hardhat");
const utils = ethers.utils;
const keccak256 = ethers.utils.keccak256;

const CATEGORY = {
	ERC20: 0,
	ERC721: 1,
	ERC1155: 2,
	unknown: 3,
};

function getEIP712Domain(address) {
	return {
		name: "ATR",
		version: "0.1",
		chainId: 31337, // Default hardhat network chain id
		verifyingContract: address
	}
};

const EIP712RecipientPermissionTypes = {
	RecipientPermission: [
		{ name: "owner", type: "address" },
		{ name: "wallet", type: "address" },
		{ name: "nonce", type: "bytes32" },
	]
}

function getPermissionObject(owner, wallet, nonce) {
	return {
		owner: owner,
		wallet: wallet,
		nonce: nonce,
	}
}

// ---------------------------------------------------------------

function getPermissionHashBytes(permissionArray, atrAddress) {
	return ethers.utils._TypedDataEncoder.hash(
		getEIP712Domain(atrAddress),
		EIP712RecipientPermissionTypes,
		getPermissionObject(...permissionArray)
	);
}

async function signPermission(permissionArray, atrAddress, signer) {
	return signer._signTypedData(
		getEIP712Domain(atrAddress),
		EIP712RecipientPermissionTypes,
		getPermissionObject(...permissionArray)
	);
}


module.exports = { CATEGORY, getPermissionHashBytes, signPermission };
