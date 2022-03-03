const { expect } = require("chai");
const { ethers } = require("hardhat");
const utils = ethers.utils;


// ⚠️ Warning: This is not the final test suite. It's just for prototype purposes.


describe("AssetTransferRights", function() {

	let ATR, atr;
	let PWNWallet, wallet;
	let Token, token;
	let owner, other;

	const IERC721 = new utils.Interface([
		"function approve(address to, uint256 tokenId) external",
		"function setApprovalForAll(address operator, bool _approved) external",
		"function transferFrom(address from, address to, uint256 tokenId) external",
		"function safeTransferFrom(address from, address to, uint256 tokenId) external",
		"function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external",
	]);

	before(async function() {
		ATR = await ethers.getContractFactory("AssetTransferRights");
		PWNWallet = await ethers.getContractFactory("PWNWallet");
		Token = await ethers.getContractFactory("UtilityToken");

		[owner, other] = await ethers.getSigners();
	});

	beforeEach(async function() {
		atr = await ATR.deploy();
		await atr.deployed();

		wallet = await PWNWallet.deploy(atr.address);
		await wallet.deployed();

		token = await Token.deploy();
		await token.deployed();
	});


	describe("Mint", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		// TODO: Implement PWNWalletProxyFactory with `isValidProxy` function to determine PWN Wallets
		xit("Should fail when sender is not PWN Wallet", async function() {
			await token.mint(other.address, 333);

			await expect(
				atr.connect(other).mintTransferRightToken(token.address, 333)
			).to.be.revertedWith("Mint is permitted only from PWN Wallet");
		});

		it("Should fail when token is already tokenised", async function() {
			await wallet.mintTransferRightToken(token.address, tokenId);

			await expect(
				wallet.mintTransferRightToken(token.address, tokenId)
			).to.be.revertedWith("Token transfer rights are already tokenised");
		});

		it("Should fail when sender is not asset owner", async function() {
			await token.mint(owner.address, 3232);

			await expect(
				wallet.mintTransferRightToken(token.address, 3232)
			).to.be.revertedWith("Token is not in wallet");
		});

		it("Should fail when token is approved to another address", async function() {
			const calldata = IERC721.encodeFunctionData("approve", [other.address, tokenId]);
			await wallet.execute(token.address, calldata);

			await expect(
				wallet.mintTransferRightToken(token.address, tokenId)
			).to.be.revertedWith("Token must not be approved to other address");
		});

		it("Should fail when token has operator", async function() {
			let calldata = IERC721.encodeFunctionData("setApprovalForAll", [other.address, true]);
			await wallet.execute(token.address, calldata);

			await expect(
				wallet.mintTransferRightToken(token.address, tokenId)
			).to.be.revertedWith("Token collection must not have any operator set");

			calldata = IERC721.encodeFunctionData("setApprovalForAll", [other.address, false]);
			await wallet.execute(token.address, calldata);

			await expect(
				wallet.mintTransferRightToken(token.address, tokenId)
			).not.to.be.reverted;
		});

		it("Should mint TR token", async function() {
			await expect(
				wallet.mintTransferRightToken(token.address, tokenId)
			).to.not.be.reverted;

			expect(await atr.ownerOf(1)).to.equal(wallet.address);
		});

	});


	describe("Burn", function() {



	});


});
