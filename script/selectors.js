const { ethers } = require("hardhat");

function selector(signature) {
	return ethers.utils.keccak256(ethers.utils.toUtf8Bytes(signature)).slice(0, 10);
}

console.log("------");
console.log("ERC20-approve:", selector("approve(address,uint256)")); // 0x095ea7b3
console.log("ERC20-increaseAllowance:", selector("increaseAllowance(address,uint256)"));// 0x39509351
console.log("ERC20-decreaseAllowance:", selector("decreaseAllowance(address,uint256)")); // 0xa457c2d7

console.log("ERC721-approve:", selector("approve(address,uint256)")); // 0x095ea7b3
console.log("ERC721-setApprovalForAll:", selector("setApprovalForAll(address,bool)")); // 0xa22cb465

console.log("ERC1155-setApprovalForAll:", selector("setApprovalForAll(address,bool)")); // 0xa22cb465

console.log("ERC777-authorizeOperator:", selector("authorizeOperator(address)")); // 0x959b8c3f
console.log("ERC777-revokeOperator:", selector("revokeOperator(address)")); // 0xfad8b32a

console.log("ERC1363-approveAndCall:", selector("approveAndCall(address,uint256)")); // 0x3177029f
console.log("ERC1363-approveAndCall(bytes):", selector("approveAndCall(address,uint256,bytes)")); // 0xcae9ca51
console.log("------");
