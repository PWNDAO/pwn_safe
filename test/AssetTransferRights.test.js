const { expect } = require("chai");
const { ethers } = require("hardhat");
const utils = ethers.utils;


describe("AssetTransferRights", function() {

	let ATR, atr;
	let wallet, walletOther;
	let factory;
	let Token, token;
	let owner, other;

	const IERC721 = new utils.Interface([
		"function approve(address to, uint256 tokenId) external",
		"function setApprovalForAll(address operator, bool _approved) external",
		"function transferFrom(address from, address to, uint256 tokenId) external",
		"function safeTransferFrom(address from, address to, uint256 tokenId) external",
		"function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external",
	]);

	const atrIface = new utils.Interface([
		"function mintAssetTransferRightsToken(address tokenAddress, uint256 tokenId) external returns (uint256)",
		"function burnAssetTransferRightsToken(uint256 atrTokenId) external",

		"function transferAssetFrom(address from, address to, uint256 atrTokenId, bool burnToken) external",
		"function safeTransferAssetFrom(address from, address to, uint256 atrTokenId, bool burnToken) external",
		"function safeTransferAssetFrom(address from, address to, uint256 atrTokenId, bool burnToken, bytes calldata data) external",
	]);

	before(async function() {
		ATR = await ethers.getContractFactory("AssetTransferRights");
		Token = await ethers.getContractFactory("UtilityToken");

		[owner, other] = await ethers.getSigners();
	});

	beforeEach(async function() {
		atr = await ATR.deploy();
		await atr.deployed();

		factory = await ethers.getContractAt("PWNWalletFactory", atr.walletFactory());

		token = await Token.deploy();
		await token.deployed();

		const walletTx = await factory.connect(owner).newWallet();
		const walletRes = await walletTx.wait();
		wallet = await ethers.getContractAt("PWNWallet", walletRes.events[1].args.walletAddress);

		const walletOtherTx = await factory.connect(other).newWallet();
		const walletOtherRes = await walletOtherTx.wait();
		walletOther = await ethers.getContractAt("PWNWallet", walletOtherRes.events[1].args.walletAddress);
	});


	describe("Mint", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		it("Should fail when sender is not PWN Wallet", async function() {
			await token.mint(other.address, 333);

			await expect(
				atr.connect(other).mintAssetTransferRightsToken(token.address, 333)
			).to.be.revertedWith("Mint is permitted only from PWN Wallet");
		});

		it("Should fail when token is already tokenised", async function() {
			const calldata = atrIface.encodeFunctionData("mintAssetTransferRightsToken", [token.address, tokenId]);
			await wallet.execute(atr.address, calldata);

			await expect(
				wallet.execute(atr.address, calldata)
			).to.be.revertedWith("Token transfer rights are already tokenised");
		});

		it("Should fail when sender is not asset owner", async function() {
			await token.mint(owner.address, 3232);

			const calldata = atrIface.encodeFunctionData("mintAssetTransferRightsToken", [token.address, 3232]);
			await expect(
				wallet.execute(atr.address, calldata)
			).to.be.revertedWith("Token is not in wallet");
		});

		it("Should fail when trying to tokenize zero address asset", async function() {
			const calldata = atrIface.encodeFunctionData("mintAssetTransferRightsToken", [ethers.constants.AddressZero, 3232]);
			await expect(
				wallet.execute(atr.address, calldata)
			).to.be.revertedWith("Cannot tokenize zero address asset");
		});

		it("Should fail when token is approved to another address", async function() {
			let calldata = IERC721.encodeFunctionData("approve", [other.address, tokenId]);
			await wallet.execute(token.address, calldata);

			calldata = atrIface.encodeFunctionData("mintAssetTransferRightsToken", [token.address, tokenId]);
			await expect(
				wallet.execute(atr.address, calldata)
			).to.be.revertedWith("Token must not be approved to other address");
		});

		it("Should fail when token has operator", async function() {
			let calldata = IERC721.encodeFunctionData("setApprovalForAll", [other.address, true]);
			await wallet.execute(token.address, calldata);

			calldata = atrIface.encodeFunctionData("mintAssetTransferRightsToken", [token.address, tokenId]);
			await expect(
				wallet.execute(atr.address, calldata)
			).to.be.revertedWith("Token collection must not have any operator set");

			calldata = IERC721.encodeFunctionData("setApprovalForAll", [other.address, false]);
			await wallet.execute(token.address, calldata);

			calldata = atrIface.encodeFunctionData("mintAssetTransferRightsToken", [token.address, tokenId]);
			await expect(
				wallet.execute(atr.address, calldata)
			).not.to.be.reverted;
		});

		it("Should mint TR token", async function() {
			const calldata = atrIface.encodeFunctionData("mintAssetTransferRightsToken", [token.address, tokenId]);
			await expect(
				wallet.execute(atr.address, calldata)
			).to.not.be.reverted;

			expect(await atr.ownerOf(1)).to.equal(wallet.address);
		});

	});


	describe("Burn", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);

			const calldata = atrIface.encodeFunctionData("mintAssetTransferRightsToken", [token.address, tokenId]);
			await wallet.execute(atr.address, calldata);
		});


		it("Should fail when sender is not ATR token owner", async function() {
			// Transfer ATR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			calldata = atrIface.encodeFunctionData("burnAssetTransferRightsToken", [1]);
			await expect(
				wallet.execute(atr.address, calldata)
			).to.be.revertedWith("Sender is not ATR token owner");
		});

		it("Should fail when ATR token is not minted", async function() {
			const calldata = atrIface.encodeFunctionData("burnAssetTransferRightsToken", [2]);
			await expect(
				wallet.execute(atr.address, calldata)
			).to.be.revertedWith("Token transfer rights are not tokenised");
		});

		it("Should fail when sender is not tokenized asset owner", async function() {
			// Transfer asset to `otherWallet`
			let calldata = atrIface.encodeFunctionData("transferAssetFrom", [wallet.address, walletOther.address, 1, false]);
			await wallet.execute(atr.address, calldata);

			calldata = atrIface.encodeFunctionData("burnAssetTransferRightsToken", [1]);
			await expect(
				wallet.execute(atr.address, calldata)
			).to.be.revertedWith("Sender is not tokenized asset owner");
		});

		it("Should burn ATR token", async function() {
			const calldata = atrIface.encodeFunctionData("burnAssetTransferRightsToken", [1]);
			await expect(
				wallet.execute(atr.address, calldata)
			).to.not.be.reverted;

			await expect(
				atr.ownerOf(1)
			).to.be.reverted;
		});

	});


	describe("Transfer asset from", async function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);

			// ATR token with id 1
			const calldata = atrIface.encodeFunctionData("mintAssetTransferRightsToken", [token.address, tokenId]);
			await wallet.execute(atr.address, calldata);
		});


		it("Should fail when it hasn't tokenized transfer rights", async function() {
			await expect(
				atr.transferAssetFrom(wallet.address, walletOther.address, 2, false)
			).to.be.revertedWith("Transfer rights are not tokenized");
		});

		it("Should fail when sender is not ATR token owner", async function() {
			await expect(
				atr.connect(owner).transferAssetFrom(wallet.address, walletOther.address, 1, false)
			).to.be.revertedWith("Sender is not ATR token owner");
		});

		it("Should fail when transferring to other than PWN Wallet and not burning ATR token", async function() {
			// Transfer ATR token to `other`
			const calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Transfer asset from `owner`s wallet via ATR token
			await expect(
				atr.connect(other).transferAssetFrom(wallet.address, other.address, 1, false)
			).to.be.revertedWith("Transfers of asset with tokenized transfer rights are allowed only to PWN Wallets");
		});

		it("Should transfer asset when transferring to other than PWN Wallet and burning ATR token", async function() {
			// Transfer ATR token to `other`
			const calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Transfer asset from `owner`s wallet via ATR token
			await expect(
				atr.connect(other).transferAssetFrom(wallet.address, other.address, 1, true)
			).to.not.be.reverted;

			expect(await token.ownerOf(tokenId)).to.equal(other.address);
		});

		it("Should fail when receiver has operator set on asset collection when not burning ATR token", async function() {
			// Transfer ATR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Set operator `other` on walletOther
			calldata = IERC721.encodeFunctionData("setApprovalForAll", [other.address, true]);
			await walletOther.connect(other).execute(token.address, calldata);

			// Transfer asset from `owner`s wallet via ATR token
			await expect(
				atr.connect(other).transferAssetFrom(wallet.address, walletOther.address, 1, false)
			).to.be.revertedWith("Receiver cannot have operator set for the token");
		});

		it("Should transfer asset when receiver has operator set on asset collection when burning ATR token", async function() {
			// Transfer ATR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Set operator `other` on walletOther
			calldata = IERC721.encodeFunctionData("setApprovalForAll", [other.address, true]);
			await walletOther.connect(other).execute(token.address, calldata);

			// Transfer asset from `owner`s wallet via ATR token
			await expect(
				atr.connect(other).transferAssetFrom(wallet.address, walletOther.address, 1, true)
			).to.not.be.reverted;

			expect(await token.ownerOf(tokenId)).to.equal(walletOther.address);
		});

		it("Should fail when asset is not in wallet", async function() {
			// Transfer ATR token to `other`
			const calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Transfer asset from `owner`s wallet via ATR token
			await expect(
				atr.connect(other).transferAssetFrom(wallet.address, walletOther.address, 1, false)
			).to.not.be.reverted;

			// Try to again transfer asset from `owner`s wallet via ATR token
			await expect(
				atr.connect(other).transferAssetFrom(wallet.address, walletOther.address, 1, false)
			).to.be.revertedWith("Asset is not in target wallet");
		});

		it("Should burn ATR token when transferring with burn flag", async function() {
			// Transfer ATR token to `other`
			const calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Transfer asset from `owner`s wallet via ATR token
			await expect(
				atr.connect(other).transferAssetFrom(wallet.address, walletOther.address, 1, true)
			).to.not.be.reverted;

			// Assets owner is `walletOther` now
			expect(await token.ownerOf(tokenId)).to.equal(walletOther.address);

			expect(await atr.isTokenized(token.address, tokenId)).to.equal(false);
			const asset = await atr.getToken(1);
			expect(asset[0]).to.equal(ethers.constants.AddressZero);
			expect(asset[1]).to.equal(0);
		});

		it("Should transfer token when sender has tokenized transfer rights", async function() {
			// Transfer ATR token to `other`
			const calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Transfer asset from `owner`s wallet via ATR token
			await expect(
				atr.connect(other).transferAssetFrom(wallet.address, walletOther.address, 1, false)
			).to.not.be.reverted;

			// Assets owner is `walletOther` now
			expect(await token.ownerOf(tokenId)).to.equal(walletOther.address);
		});

	});

});
