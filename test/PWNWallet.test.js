const { expect } = require("chai");
const { ethers } = require("hardhat");
const utils = ethers.utils;


// ⚠️ Warning: This is not the final test suite. It's just for prototype purposes.


describe("PWNWallet", function() {

	let ATR, atr;
	let wallet, walletOther;
	let factory;
	let Token, token;
	let owner, other;

	const tokenIface = new utils.Interface([
		"function utilityEmpty() external",
		"function burn(uint256 tokenId) external",
	]);

	const factoryIface = new utils.Interface([
		"event NewWallet(address indexed walletAddress)",
	]);

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

		"function transferAsset(address to, uint256 atrTokenId) external",
		"function safeTransferAsset(address to, uint256 atrTokenId) external",
		"function safeTransferAsset(address to, uint256 atrTokenId, bytes calldata data) external",
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


	describe("Execute", function() {

		it("Should fail when sender is not wallet owner", async function() {
			const calldata = tokenIface.encodeFunctionData("utilityEmpty", []);
			await expect(
				wallet.connect(other).execute(token.address, calldata)
			).to.be.reverted;
		});

		it("Should succeed when sender is wallet owner", async function() {
			const calldata = tokenIface.encodeFunctionData("utilityEmpty", []);

			await expect(
				wallet.connect(owner).execute(token.address, calldata)
			).to.not.be.reverted;

			const encodedReturnValue = utils.defaultAbiCoder.encode(
				["bytes32"],
				[utils.keccak256(utils.toUtf8Bytes("success"))]
			);
			expect(await token.encodedReturnValue()).to.equal(encodedReturnValue);
		});

	});


	describe("Approve", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		it("Should set approved address when asset is not tokenised", async function() {
			const calldata = IERC721.encodeFunctionData("approve", [other.address, tokenId]);
			await expect(
				wallet.connect(owner).execute(token.address, calldata)
			).to.not.be.reverted;

			expect(await token.getApproved(tokenId)).to.equal(other.address);
		});

		it("Should fail when asset is tokenised", async function() {
			// ATR token with id 1
			let calldata = atrIface.encodeFunctionData("mintAssetTransferRightsToken", [token.address, tokenId]);
			await wallet.execute(atr.address, calldata);

			calldata = IERC721.encodeFunctionData("approve", [other.address, tokenId]);
			await expect(
				wallet.connect(owner).execute(token.address, calldata)
			).to.be.revertedWith("Cannot approve token while having transfer right token minted");
		});

		it("Should set approved address when asset had ATR token and then was burned", async function() {
			// mint ATR token
			let calldata = atrIface.encodeFunctionData("mintAssetTransferRightsToken", [token.address, tokenId]);
			await wallet.execute(atr.address, calldata);

			// try to approve
			calldata = IERC721.encodeFunctionData("approve", [other.address, tokenId]);
			await expect(
				wallet.connect(owner).execute(token.address, calldata)
			).to.be.reverted;

			// burn ATR token
			calldata = atrIface.encodeFunctionData("burnAssetTransferRightsToken", [1]);
			await wallet.execute(atr.address, calldata);

			// approve
			calldata = IERC721.encodeFunctionData("approve", [other.address, tokenId]);
			await expect(
				wallet.connect(owner).execute(token.address, calldata)
			).to.not.be.reverted;

			expect(await token.getApproved(tokenId)).to.equal(other.address);
		});

	});


	describe("Set approval for all", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		it("Should set operator when any asset from collection is not tokenised", async function() {
			const calldata = IERC721.encodeFunctionData("setApprovalForAll", [other.address, true]);
			await expect(
				wallet.execute(token.address, calldata)
			).to.not.be.reverted;

			expect(await token.isApprovedForAll(wallet.address, other.address)).to.equal(true);
		});

		it("Should fail when any asset from collection is tokenised", async function() {
			// mint ATR token
			let calldata = atrIface.encodeFunctionData("mintAssetTransferRightsToken", [token.address, tokenId]);
			await wallet.execute(atr.address, calldata);

			// try to set approve for all
			calldata = IERC721.encodeFunctionData("setApprovalForAll", [other.address, true]);
			await expect(
				wallet.execute(token.address, calldata)
			).to.be.revertedWith("Cannot approve all while having transfer right token minted");
		});

		it("Should set operator when asset had ATR token and then was burned", async function() {
			// mint ATR token
			let calldata = atrIface.encodeFunctionData("mintAssetTransferRightsToken", [token.address, tokenId]);
			await wallet.execute(atr.address, calldata);

			// try to set approve for all
			calldata = IERC721.encodeFunctionData("setApprovalForAll", [other.address, true]);
			await expect(
				wallet.execute(token.address, calldata)
			).to.be.reverted;

			// burn ATR token
			calldata = atrIface.encodeFunctionData("burnAssetTransferRightsToken", [1]);
			await wallet.execute(atr.address, calldata);

			// set approval for all
			calldata = IERC721.encodeFunctionData("setApprovalForAll", [other.address, true]);
			await expect(
				wallet.execute(token.address, calldata)
			).to.not.be.reverted;

			expect(await token.isApprovedForAll(wallet.address, other.address)).to.equal(true);
		});

	});


	describe("Transfer from", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		it("Should transfer token when it hasn't tokenized transfer rights", async function() {
			const calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, tokenId]);
			await expect(
				wallet.execute(token.address, calldata)
			).to.not.be.reverted;
		});

		it("Should fail when it has tokenized transfer rights", async function() {
			// mint ATR token
			let calldata = atrIface.encodeFunctionData("mintAssetTransferRightsToken", [token.address, tokenId]);
			await wallet.execute(atr.address, calldata);

			// transfer ATR token to `other`
			calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// try to transfer asset as wallet owner
			calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, tokenId]);
			await expect(
				wallet.execute(token.address, calldata)
			).to.be.reverted;
		});
	});


	describe("Transfer asset", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);

			// ATR token with id 1
			const calldata = atrIface.encodeFunctionData("mintAssetTransferRightsToken", [token.address, tokenId]);
			await wallet.execute(atr.address, calldata);
		});


		it("Should fail when sender is not ATR contract", async function() {
			await expect(
				wallet.transferAsset(walletOther.address, token.address, 1)
			).to.be.revertedWith("Sender is not asset transfer rights contract");
		});

		xit("Should transfer asset to receiver", async function() {
			// Mock wallet, set _atr to some address, call from that address
		});

	});

	// TODO: Test adding / removing operators

});
