const { expect } = require("chai");
const { ethers } = require("hardhat");
const utils = ethers.utils;

describe("PWNWallet", function() {

	let PWNWallet, wallet;
	let Token, token;
	let owner, other;

	const tokenIface = new utils.Interface([
		"function utilityEmpty() external",
		"function utilityParams(uint256 tokenId, address arg2, string memory arg3) external",
		"function utilityEth(uint256 tokenId) external payable",
	]);

	const IERC721 = new utils.Interface([
		"function approve(address to, uint256 tokenId) external",
		"function setApprovalForAll(address operator, bool _approved) external",
	]);

	before(async function() {
		PWNWallet = await ethers.getContractFactory("PWNWallet");
		Token = await ethers.getContractFactory("UtilityToken");

		[owner, other] = await ethers.getSigners();
	});

	beforeEach(async function() {
		wallet = await PWNWallet.deploy();

		token = await Token.deploy();
		await token.deployed();
	});


	describe("Execute", function() {

		it("Should fail if sender is not wallet owner", async function() {
			const calldata = tokenIface.encodeFunctionData("utilityEmpty", []);

			await expect(
				wallet.connect(other).execute(token.address, calldata)
			).to.be.reverted;
		});

		it("Should succeed if sender is wallet owner", async function() {
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


	describe("Mint", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		it("Should fail if token is already tokenised", async function() {
			await wallet.mintTransferRightToken(token.address, tokenId);

			await expect(
				wallet.mintTransferRightToken(token.address, tokenId)
			).to.be.revertedWith("Token transfer rights are already tokenised");
		});

		it("Should fail if token is not in wallet", async function() {
			await token.mint(owner.address, 3232);

			await expect(
				wallet.mintTransferRightToken(token.address, 3232)
			).to.be.revertedWith("Token is not in wallet");
		});

		it("Should fail if token is approved to another address", async function() {
			const calldata = IERC721.encodeFunctionData("approve", [other.address, tokenId]);
			await wallet.execute(token.address, calldata);

			await expect(
				wallet.mintTransferRightToken(token.address, tokenId)
			).to.be.revertedWith("Token must not be approved to other address");
		});

		it("Should fail if token has operator", async function() {
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

			expect(await wallet.ownerOf(1)).to.equal(wallet.address);
		});

	});


	describe("Approve", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		it("Should set approved address if asset is not tokenised", async function() {
			const calldata = IERC721.encodeFunctionData("approve", [other.address, tokenId]);

			await expect(
				wallet.execute(token.address, calldata)
			).to.not.be.reverted;

			expect(await token.getApproved(tokenId)).to.equal(other.address);
		});

		it("Should fail if asset is tokenised", async function() {
			await wallet.mintTransferRightToken(token.address, tokenId);

			const calldata = IERC721.encodeFunctionData("approve", [other.address, tokenId]);

			await expect(
				wallet.execute(token.address, calldata)
			).to.be.revertedWith("Cannot approve token while having transfer right token minted");
		});

	});


	describe("Approve all", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		it("Should set operator if any asset from collection is not tokenised", async function() {
			let calldata = IERC721.encodeFunctionData("setApprovalForAll", [other.address, true]);

			await expect(
				wallet.execute(token.address, calldata)
			).to.not.be.reverted;

			expect(await token.isApprovedForAll(wallet.address, other.address)).to.equal(true);
		});

		it("Should fail if any asset from collection is tokenised", async function() {
			await wallet.mintTransferRightToken(token.address, tokenId);

			let calldata = IERC721.encodeFunctionData("setApprovalForAll", [other.address, true]);

			await expect(
				wallet.execute(token.address, calldata)
			).to.be.revertedWith("Cannot approve all while having transfer right token minted");
		});

		// Should update operator set

	});


	describe("Transfer from", function() {

	});


	describe("Safe transfer from", function() {

	});


	describe("Safe transfer from with data", function() {

	});

	// TODO: Test adding / removing operators

});
