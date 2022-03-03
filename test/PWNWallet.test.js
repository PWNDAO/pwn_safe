const { expect } = require("chai");
const { ethers } = require("hardhat");
const utils = ethers.utils;


// ⚠️ Warning: This is not the final test suite. It's just for prototype purposes.


describe("PWNWallet", function() {

	let ATR, atr;
	let PWNWallet, wallet, walletOther;
	let Token, token;
	let owner, other;

	const tokenIface = new utils.Interface([
		"function utilityEmpty() external",
		"function burn(uint256 tokenId) external",
	]);

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

		walletOther = await PWNWallet.deploy(atr.address);
		await walletOther.deployed();

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

		it("Should fail when it has tokenized transfer rights", async function() {
			// Mint ATR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer ATR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

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

		it("Should fail when it has tokenized transfer rights", async function() {
			// Mint ATR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer ATR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

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

		it("Should fail when it has tokenized transfer rights", async function() {
			// Mint ATR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer ATR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Try to transfer asset as wallet owner
			calldata = IERC721.encodeFunctionData("safeTransferFrom(address,address,uint256,bytes)", [wallet.address, other.address, tokenId, "0x"]);
			await expect(
				wallet.execute(token.address, calldata)
			).to.be.reverted;
		});
	});


	describe("Burn", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		it("Should burn token when it hasn't tokenized transfer rights", async function() {
			const calldata = tokenIface.encodeFunctionData("burn", [tokenId]);
			await expect(
				wallet.execute(token.address, calldata)
			).to.not.be.reverted;
		});

		it("Should fail when it has tokenized transfer rights", async function() {
			// Mint ATR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer ATR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Try to burn asset as wallet owner
			calldata = tokenIface.encodeFunctionData("burn", [tokenId]);
			await expect(
				wallet.execute(token.address, calldata)
			).to.be.reverted;
		});
	});


	describe("Transfer from with ATR token", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		it("Should fail when it hasn't tokenized transfer rights", async function() {
			await expect(
				wallet.connect(other).transferTokenFrom(wallet.address, walletOther.address, 1, false)
			).to.be.revertedWith("Transfer rights are not tokenized");
		});

		it("Should fail when sender is not ATR token owner", async function() {
			// Mint ATR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer ATR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Transfer asset from `owner`s wallet via ATR token
			await expect(
				wallet.connect(owner).transferTokenFrom(wallet.address, walletOther.address, 1, false)
			).to.be.revertedWith("Sender is not ATR token owner");
		});

		it("Should fail when receiver has operator set on asset collection", async function() {
			// Mint ATR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer ATR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Set operator `other` on walletOther
			calldata = IERC721.encodeFunctionData("setApprovalForAll", [other.address, true]);
			await walletOther.execute(token.address, calldata);

			// Transfer asset from `owner`s wallet via ATR token
			await expect(
				wallet.connect(other).transferTokenFrom(wallet.address, walletOther.address, 1, false)
			).to.be.revertedWith("Receiver cannot have operator set for the token");
		});

		it("Should transfer token when sender has tokenized transfer rights", async function() {
			// Mint ATR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer ATR token to `other`
			const calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Transfer asset from `owner`s wallet via ATR token
			await expect(
				wallet.connect(other).transferTokenFrom(wallet.address, walletOther.address, 1, false)
			).to.not.be.reverted;

			// Assets owner is `other` now
			expect(await token.ownerOf(tokenId)).to.equal(walletOther.address);
		});

		// const numberOfTokens = 100;
		// it(`Gas report for ${numberOfTokens} tokenized assets`, async function() {
		// 	for (var i = 1; i < numberOfTokens + 1; i++) {
		// 		// Mint token
		// 		await token.mint(wallet.address, i);

		// 		// Mint ATR token
		// 		await wallet.mintTransferRightToken(token.address, i);

		// 		// Transfer ATR token to `other`
		// 		const calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, i]);
		// 		await wallet.execute(atr.address, calldata);
		// 	}

		// 	const id = 70;

		// 	// Transfer asset from `owner`s wallet via ATR token
		// 	await expect(
		// 		wallet.connect(other).transferTokenFrom(wallet.address, walletOther.address, id, false)
		// 	).to.not.be.reverted;

		// 	// Assets owner is `other` now
		// 	expect(await token.ownerOf(id)).to.equal(walletOther.address);
		// });

	});


	describe("Safe transfer from with ATR token", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		it("Should fail when it hasn't tokenized transfer rights", async function() {
			await expect(
				wallet.connect(other)["safeTransferTokenFrom(address,address,uint256,bool)"](wallet.address, other.address, 1, false)
			).to.be.revertedWith("Transfer rights are not tokenized");
		});

		it("Should fail when sender is not ATR token owner", async function() {
			// Mint ATR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer ATR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Transfer asset from `owner`s wallet via ATR token
			await expect(
				wallet.connect(owner)["safeTransferTokenFrom(address,address,uint256,bool)"](wallet.address, walletOther.address, 1, false)
			).to.be.revertedWith("Sender is not ATR token owner");
		});

		it("Should fail when receiver has operator set on asset collection", async function() {
			// Mint ATR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer ATR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Set operator `other` on walletOther
			calldata = IERC721.encodeFunctionData("setApprovalForAll", [other.address, true]);
			await walletOther.execute(token.address, calldata);

			// Transfer asset from `owner`s wallet via ATR token
			await expect(
				wallet.connect(other)["safeTransferTokenFrom(address,address,uint256,bool)"](wallet.address, walletOther.address, 1, false)
			).to.be.revertedWith("Receiver cannot have operator set for the token");
		});

		it("Should transfer token when sender has tokenized transfer rights", async function() {
			// Mint ATR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer ATR token to `other`
			const calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Transfer asset from `owner`s wallet via ATR token
			await expect(
				wallet.connect(other)["safeTransferTokenFrom(address,address,uint256,bool)"](wallet.address, walletOther.address, 1, false)
			).to.not.be.reverted;

			// Assets owner is `other` now
			expect(await token.ownerOf(tokenId)).to.equal(walletOther.address);
		});

	});


	describe("Safe transfer from with data with ATR token", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


		it("Should fail when it hasn't tokenized transfer rights", async function() {
			await expect(
				wallet.connect(other)["safeTransferTokenFrom(address,address,uint256,bool,bytes)"](wallet.address, walletOther.address, 1, false, "0x")
			).to.be.revertedWith("Transfer rights are not tokenized");
		});

		it("Should fail when sender is not ATR token owner", async function() {
			// Mint ATR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer ATR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Transfer asset from `owner`s wallet via ATR token
			await expect(
				wallet.connect(owner)["safeTransferTokenFrom(address,address,uint256,bool,bytes)"](wallet.address, walletOther.address, 1, false, "0x")
			).to.be.revertedWith("Sender is not ATR token owner");
		});

		it("Should fail when receiver has operator set on asset collection", async function() {
			// Mint ATR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer ATR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Set operator `other` on walletOther
			calldata = IERC721.encodeFunctionData("setApprovalForAll", [other.address, true]);
			await walletOther.execute(token.address, calldata);

			// Transfer asset from `owner`s wallet via ATR token
			await expect(
				wallet.connect(other)["safeTransferTokenFrom(address,address,uint256,bool,bytes)"](wallet.address, walletOther.address, 1, false, "0x")
			).to.be.revertedWith("Receiver cannot have operator set for the token");
		});

		it("Should transfer token when sender has tokenized transfer rights", async function() {
			// Mint ATR token
			await wallet.mintTransferRightToken(token.address, tokenId);

			// Transfer ATR token to `other`
			let calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1]);
			await wallet.execute(atr.address, calldata);

			// Transfer asset from `owner`s wallet via ATR token
			await expect(
				wallet.connect(other)["safeTransferTokenFrom(address,address,uint256,bool,bytes)"](wallet.address, walletOther.address, 1, false, "0x")
			).to.not.be.reverted;

			// Assets owner is `other` now
			expect(await token.ownerOf(tokenId)).to.equal(walletOther.address);
		});

	});

	// TODO: Test adding / removing operators

});
