const { expect } = require("chai");
const { ethers } = require("hardhat");
const utils = ethers.utils;


describe("AssetTransferRights", function() {

	let ATR, atr;
	let wallet, walletOther;
	let factory;
	let Token, token;
	let owner, other;

	const tokenIface = new utils.Interface([
		"function utilityEmpty() external",
	]);

	const IERC721 = new utils.Interface([
		"function approve(address to, uint256 tokenId) external",
		"function setApprovalForAll(address operator, bool _approved) external",
		"function transferFrom(address from, address to, uint256 tokenId) external",
		"function safeTransferFrom(address from, address to, uint256 tokenId) external",
		"function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external",
	]);

	const atrIface = new utils.Interface([
		"function mintAssetTransferRightsToken(tuple(address assetAddress, uint8 category, uint256 amount, uint256 id)) external returns (uint256)",
		"function burnAssetTransferRightsToken(uint256 atrTokenId) external",
		"function transferAssetFrom(address from, address to, uint256 atrTokenId, bool burnToken) external",
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
				atr.connect(other).mintAssetTransferRightsToken( [token.address, 1, 1, 333] )
			).to.be.revertedWith("Mint is permitted only from PWN Wallet");
		});

		it("Should fail when token is already tokenised", async function() {
			await wallet.mintAssetTransferRightsToken([token.address, 1, 1, tokenId]);

			await expect(
				wallet.mintAssetTransferRightsToken([token.address, 1, 1, tokenId])
			).to.be.revertedWith("Not enough balance to tokenize asset transfer rights");
		});

		it("Should fail when sender is not asset owner", async function() {
			await token.mint(owner.address, 3232);

			await expect(
				wallet.mintAssetTransferRightsToken([token.address, 1, 1, 3232])
			).to.be.revertedWith("Not enough balance to tokenize asset transfer rights");
		});

		it("Should fail when trying to tokenize zero address asset", async function() {
			const calldata = atrIface.encodeFunctionData("mintAssetTransferRightsToken", [ [ethers.constants.AddressZero, 1, 1, 3232] ]);
			await expect(
				wallet.mintAssetTransferRightsToken([ethers.constants.AddressZero, 1, 1, 3232])
			).to.be.revertedWith("Cannot tokenize zero address asset");
		});

		it("Should mint TR token", async function() {
			await expect(
				wallet.mintAssetTransferRightsToken([token.address, 1, 1, tokenId])
			).to.not.be.reverted;

			expect(await atr.ownerOf(1)).to.equal(wallet.address);
		});

	});


	describe("Burn", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);

			// ATR token with id 1
			await wallet.mintAssetTransferRightsToken([token.address, 1, 1, tokenId]);
		});


		it("Should fail when sender is not ATR token owner", async function() {
			// Transfer ATR token to `other`
			const calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			await expect(
				wallet.burnAssetTransferRightsToken(1)
			).to.be.revertedWith("Sender is not ATR token owner");
		});

		it("Should fail when ATR token is not minted", async function() {
			await expect(
				wallet.burnAssetTransferRightsToken(2)
			).to.be.revertedWith("Asset transfer rights are not tokenized");
		});

		it("Should fail when sender is not tokenized asset owner", async function() {
			// Transfer asset to `otherWallet`
			const calldata = atrIface.encodeFunctionData("transferAssetFrom", [wallet.address, walletOther.address, 1, false]);
			await wallet.execute(atr.address, calldata);

			await expect(
				wallet.burnAssetTransferRightsToken(1)
			).to.be.revertedWith("Sender does not have enough amount of tokenized asset");
		});

		it("Should burn ATR token", async function() {
			await expect(
				wallet.burnAssetTransferRightsToken(1)
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
			await wallet.mintAssetTransferRightsToken([token.address, 1, 1, tokenId]);
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

		it("Should fail when transferring asset to self", async function() {
			// Transfer ATR token to `other`
			const calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Transfer asset from and to `owner`s wallet via ATR token
			await expect(
				atr.connect(other).transferAssetFrom(wallet.address, wallet.address, 1, false)
			).to.be.revertedWith("Transferring asset to same address");
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

			await expect(atr.ownerOf(1)).to.be.reverted;
			const asset = await atr.getAsset(1);
			expect(asset[0]).to.equal(ethers.constants.AddressZero);
			expect(asset[3]).to.equal(0);
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
