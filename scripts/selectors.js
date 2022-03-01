const { ethers } = require("hardhat");

function selector(signature) {
	return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(signature)).slice(0, 10);
}

console.log("------");
console.log("setApprovalForAll:\t", selector("setApprovalForAll(address,bool)"));
console.log("approve:\t\t", selector("approve(address,uint256)"));
console.log("transferFrom:\t\t", selector("transferFrom(address,address,uint256)"));
console.log("safeTransferFrom:\t", selector("safeTransferFrom(address,address,uint256)"));
console.log("safeTransferFromD:\t", selector("safeTransferFrom(address,address,uint256,bytes)"));
console.log("------");
