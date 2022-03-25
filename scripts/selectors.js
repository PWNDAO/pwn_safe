const { ethers } = require("hardhat");

function selector(signature) {
	return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(signature)).slice(0, 10);
}

console.log("------");
console.log("ERC721-setApprovalForAll:\t", selector("setApprovalForAll(address,bool)"));
console.log("ERC721-approve:\t\t", selector("approve(address,uint256)"));
console.log("------");
