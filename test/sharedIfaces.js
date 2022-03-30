const { ethers } = require("hardhat");


const walletFactory = new ethers.utils.Interface([
	"event NewWallet(address indexed walletAddress)",
]);

const ERC20 = new ethers.utils.Interface([
	"function totalSupply() external view returns (uint256)",
	"function balanceOf(address account) external view returns (uint256)",
	"function transfer(address to, uint256 amount) external returns (bool)",
	"function allowance(address owner, address spender) external view returns (uint256)",
	"function approve(address spender, uint256 amount) external returns (bool)",
	"function transferFrom(address from, address to, uint256 amount) external returns (bool)",
	"function increaseAllowance(address spender, uint256 addedValue) public returns (bool)",
	"function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool)",
]);

const ERC721 = new ethers.utils.Interface([
	"function balanceOf(address owner) external view returns (uint256 balance)",
	"function ownerOf(uint256 tokenId) external view returns (address owner)",
	"function safeTransferFrom(address from, address to, uint256 tokenId) external",
	"function transferFrom(address from, address to, uint256 tokenId) external",
	"function approve(address to, uint256 tokenId) external",
	"function getApproved(uint256 tokenId) external view returns (address operator)",
	"function setApprovalForAll(address operator, bool _approved) external",
	"function isApprovedForAll(address owner, address operator) external view returns (bool)",
	"function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external",
]);

const ERC1155 = new ethers.utils.Interface([
	"function balanceOf(address account, uint256 id) external view returns (uint256)",
	"function balanceOfBatch(address[] calldata accounts, uint256[] calldata ids) external view returns (uint256[] memory)",
	"function setApprovalForAll(address operator, bool approved) external",
	"function isApprovedForAll(address account, address operator) external view returns (bool)",
	"function safeTransferFrom(address from, address to, uint256 id, uint256 amount, bytes calldata data) external",
	"function safeBatchTransferFrom(address from, address to, uint256[] calldata ids, uint256[] calldata amounts, bytes calldata data) external",
]);

const T20 = new ethers.utils.Interface([
	"function foo() external",
	"function mint(address owner, uint256 amount) external",
	"function burn(address owner, uint256 amount) external",
]);

const T721 = new ethers.utils.Interface([
	"function foo() external",
	"function mint(address owner, uint256 tokenId) external",
	"function burn(uint256 tokenId) external",
	"function forceTransfer(address from, address to, uint256 tokenId) external",
]);

const T1155 = new ethers.utils.Interface([
	"function foo() external",
	"function mint(address owner, uint256 id, uint256 amount) external",
	"function burn(address owner, uint256 id, uint256 amount) external",
]);

const ATR = new ethers.utils.Interface([
	"function mintAssetTransferRightsToken(tuple(address assetAddress, uint8 category, uint256 amount, uint256 id)) external returns (uint256)",
	"function burnAssetTransferRightsToken(uint256 atrTokenId) external",
	"function transferAssetFrom(address from, address to, uint256 atrTokenId, bool burnToken) external",
	"function getAsset(uint256 atrTokenId) public view returns (tuple(address assetAddress, uint8 category, uint256 amount, uint256 id))",
	"function ownedAssetATRIds() public view returns (uint256[] memory)",
	"function ownedFromCollection(address assetAddress) external view returns (uint256)",
]);

module.exports = { walletFactory, ERC20, ERC721, ERC1155, T20, T721, T1155, ATR };
