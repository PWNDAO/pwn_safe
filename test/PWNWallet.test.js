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
		"function transferFrom(address from, address to, uint256 tokenId) external",
		"function safeTransferFrom(address from, address to, uint256 tokenId) external",
		"function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external",
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


	describe("Mint", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		it("Should fail when token is already tokenised", async function() {
			await wallet.mintTransferRightToken(token.address, tokenId);

			await expect(
				wallet.mintTransferRightToken(token.address, tokenId)
			).to.be.revertedWith("Token transfer rights are already tokenised");
		});

		it("Should fail when token is not in wallet", async function() {
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

			expect(await wallet.ownerOf(1)).to.equal(wallet.address);
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
				wallet.execute(token.address, calldata)
			).to.not.be.reverted;

			expect(await token.getApproved(tokenId)).to.equal(other.address);
		});

		it("Should fail when asset is tokenised", async function() {
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


		it("Should set operator when any asset from collection is not tokenised", async function() {
			const calldata = IERC721.encodeFunctionData("setApprovalForAll", [other.address, true]);
			await expect(
				wallet.execute(token.address, calldata)
			).to.not.be.reverted;

			expect(await token.isApprovedForAll(wallet.address, other.address)).to.equal(true);
		});

		it("Should fail when any asset from collection is tokenised", async function() {
			await wallet.mintTransferRightToken(token.address, tokenId);

			const calldata = IERC721.encodeFunctionData("setApprovalForAll", [other.address, true]);
			await expect(
				wallet.execute(token.address, calldata)
			).to.be.revertedWith("Cannot approve all while having transfer right token minted");
		});

		xit("Should update operator set");

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

		it("Should faile when it has tokenized transfer rights", async function() {
			// Mint TR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer TR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(wallet.address, calldata);

			// Try to transfer asset as wallet owner
			calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, tokenId]);
			await expect(
				wallet.execute(token.address, calldata)
			).to.be.reverted;
		});
	});

	describe("Safe transfer from", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		it("Should transfer token when it hasn't tokenized transfer rights", async function() {
			const calldata = IERC721.encodeFunctionData("safeTransferFrom(address,address,uint256)", [wallet.address, other.address, tokenId]);
			await expect(
				wallet.execute(token.address, calldata)
			).to.not.be.reverted;
		});

		it("Should faile when it has tokenized transfer rights", async function() {
			// Mint TR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer TR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(wallet.address, calldata);

			// Try to transfer asset as wallet owner
			calldata = IERC721.encodeFunctionData("safeTransferFrom(address,address,uint256)", [wallet.address, other.address, tokenId]);
			await expect(
				wallet.execute(token.address, calldata)
			).to.be.reverted;
		});
	});

	describe("Safe transfer from with data", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		it("Should transfer token when it hasn't tokenized transfer rights", async function() {
			const calldata = IERC721.encodeFunctionData("safeTransferFrom(address,address,uint256,bytes)", [wallet.address, other.address, tokenId, "0x"]);
			await expect(
				wallet.execute(token.address, calldata)
			).to.not.be.reverted;
		});

		it("Should faile when it has tokenized transfer rights which is not in wallet", async function() {
			// Mint TR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer TR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(wallet.address, calldata);

			// Try to transfer asset as wallet owner
			calldata = IERC721.encodeFunctionData("safeTransferFrom(address,address,uint256,bytes)", [wallet.address, other.address, tokenId, "0x"]);
			await expect(
				wallet.execute(token.address, calldata)
			).to.be.reverted;
		});
	});


	describe("Transfer from with TR token", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		it("Should fail when it hasn't tokenized transfer rights", async function() {
			await expect(
				wallet.connect(other).transferTokenFrom(wallet.address, other.address, token.address, tokenId, 1)
			).to.be.revertedWith("Transfer rights are not tokenized");
		});

		it("Should fail when sender is not TR token owner", async function() {
			// Mint TR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer TR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(wallet.address, calldata);

			// Transfer asset from `owner`s wallet via TR token
			await expect(
				wallet.connect(owner).transferTokenFrom(wallet.address, other.address, token.address, tokenId, 1)
			).to.be.revertedWith("Sender is not owner of TR token");
		});

		it("Should fail when given TR token id doesn't match tokenized asset", async function() {
			// Mint other asset
			await token.mint(wallet.address, 1000);

			// Mint TR token for first asset (TR token id 1)
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Mint TR token for second asset (TR token id 2)
			await wallet.mintTransferRightToken(token.address, 1000);

			// Transfer TR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(wallet.address, calldata);

			// Transfer asset from `owner`s wallet via TR token
			await expect(
				wallet.connect(other).transferTokenFrom(wallet.address, other.address, token.address, 1000, 1)
			).to.be.revertedWith("TR token id did not tokenized given asset");
		});

		it("Should transfer token when sender has tokenized transfer rights", async function() {
			// Mint TR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer TR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(wallet.address, calldata);

			// Transfer asset from `owner`s wallet via TR token
			await expect(
				wallet.connect(other).transferTokenFrom(wallet.address, other.address, token.address, tokenId, 1)
			).to.not.be.reverted;

			// Assets owner is `other` now
			expect(await token.ownerOf(tokenId)).to.equal(other.address);
		});

	});


	describe("Safe transfer from with TR token", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		it("Should fail when it hasn't tokenized transfer rights", async function() {
			await expect(
				wallet.connect(other)["safeTransferTokenFrom(address,address,address,uint256,uint256)"](wallet.address, other.address, token.address, tokenId, 1)
			).to.be.revertedWith("Transfer rights are not tokenized");
		});

		it("Should fail when sender is not TR token owner", async function() {
			// Mint TR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer TR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(wallet.address, calldata);

			// Transfer asset from `owner`s wallet via TR token
			await expect(
				wallet.connect(owner)["safeTransferTokenFrom(address,address,address,uint256,uint256)"](wallet.address, other.address, token.address, tokenId, 1)
			).to.be.revertedWith("Sender is not owner of TR token");
		});

		it("Should fail when given TR token id doesn't match tokenized asset", async function() {
			// Mint other asset
			await token.mint(wallet.address, 1000);

			// Mint TR token for first asset (TR token id 1)
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Mint TR token for second asset (TR token id 2)
			await wallet.mintTransferRightToken(token.address, 1000);

			// Transfer TR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(wallet.address, calldata);

			// Transfer asset from `owner`s wallet via TR token
			await expect(
				wallet.connect(other)["safeTransferTokenFrom(address,address,address,uint256,uint256)"](wallet.address, other.address, token.address, 1000, 1)
			).to.be.revertedWith("TR token id did not tokenized given asset");
		});

		it("Should transfer token when sender has tokenized transfer rights", async function() {
			// Mint TR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer TR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(wallet.address, calldata);

			// Transfer asset from `owner`s wallet via TR token
			await expect(
				wallet.connect(other)["safeTransferTokenFrom(address,address,address,uint256,uint256)"](wallet.address, other.address, token.address, tokenId, 1)
			).to.not.be.reverted;

			// Assets owner is `other` now
			expect(await token.ownerOf(tokenId)).to.equal(other.address);
		});

	});


	describe("Safe transfer from with data with TR token", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		it("Should fail when it hasn't tokenized transfer rights", async function() {
			await expect(
				wallet.connect(other)["safeTransferTokenFrom(address,address,address,uint256,uint256,bytes)"](wallet.address, other.address, token.address, tokenId, 1, "0x")
			).to.be.revertedWith("Transfer rights are not tokenized");
		});

		it("Should fail when sender is not TR token owner", async function() {
			// Mint TR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer TR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(wallet.address, calldata);

			// Transfer asset from `owner`s wallet via TR token
			await expect(
				wallet.connect(owner)["safeTransferTokenFrom(address,address,address,uint256,uint256,bytes)"](wallet.address, other.address, token.address, tokenId, 1, "0x")
			).to.be.revertedWith("Sender is not owner of TR token");
		});

		it("Should fail when given TR token id doesn't match tokenized asset", async function() {
			// Mint other asset
			await token.mint(wallet.address, 1000);

			// Mint TR token for first asset (TR token id 1)
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Mint TR token for second asset (TR token id 2)
			await wallet.mintTransferRightToken(token.address, 1000);

			// Transfer TR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(wallet.address, calldata);

			// Transfer asset from `owner`s wallet via TR token
			await expect(
				wallet.connect(other)["safeTransferTokenFrom(address,address,address,uint256,uint256,bytes)"](wallet.address, other.address, token.address, 1000, 1, "0x")
			).to.be.revertedWith("TR token id did not tokenized given asset");
		});

		it("Should transfer token when sender has tokenized transfer rights", async function() {
			// Mint TR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer TR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(wallet.address, calldata);

			// Transfer asset from `owner`s wallet via TR token
			await expect(
				wallet.connect(other)["safeTransferTokenFrom(address,address,address,uint256,uint256,bytes)"](wallet.address, other.address, token.address, tokenId, 1, "0x")
			).to.not.be.reverted;

			// Assets owner is `other` now
			expect(await token.ownerOf(tokenId)).to.equal(other.address);
		});

	});

	// TODO: Test adding / removing operators

});
