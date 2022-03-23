const chai = require("chai");
const { ethers } = require("hardhat");
const { smock } = require("@defi-wonderland/smock");
const utils = ethers.utils;

const expect = chai.expect;
chai.use(smock.matchers);


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


	describe("Execute", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await token.mint(wallet.address, tokenId);
		});


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

		it("Should transfer token when it hasn't tokenized transfer rights", async function() {
			const calldata = IERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, tokenId]);
			await expect(
				wallet.execute(token.address, calldata)
			).to.not.be.reverted;
		});

		it("Should fail when it has tokenized transfer rights", async function() {
			// mint ATR token
			await wallet.mintAssetTransferRightsToken([token.address, 1, 1, tokenId]);

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
			await wallet.mintAssetTransferRightsToken([token.address, 1, 1, tokenId]);
		});


		it("Should fail when sender is not ATR contract", async function() {
			await expect(
				wallet.transferAsset([token.address, 1, 1, 1], walletOther.address)
			).to.be.revertedWith("Sender is not asset transfer rights contract");
		});

		it("Should transfer asset to receiver", async function() {
			const fakeToken = await smock.fake("UtilityToken");
			const mockWalletFactory = await smock.mock("PWNWallet");
			const mockWallet = await mockWalletFactory.deploy();
			await mockWallet.initialize(owner.address, other.address);

			await mockWallet.connect(other).transferAsset([fakeToken.address, 1, 1, 1], walletOther.address);

			expect(fakeToken.transferFrom).to.have.been.calledOnce;
		});

	});


	describe("Mint ATR token", function() {

		it("Should call mint on ATR contract", async function() {
			const fakeAtr = await smock.fake("AssetTransferRights");
			const mockWalletFactory = await smock.mock("PWNWallet");
			const mockWallet = await mockWalletFactory.deploy();
			await mockWallet.initialize(owner.address, fakeAtr.address);

			await mockWallet.mintAssetTransferRightsToken([token.address, 1, 1, 40]);

			expect(fakeAtr.mintAssetTransferRightsToken).to.have.been.calledOnceWith([token.address, 1, 1, 40]);
		});

	});


	describe("Burn ATR token", function() {

		it("Should call burn on ATR contract", async function() {
			const fakeAtr = await smock.fake("AssetTransferRights");
			const mockWalletFactory = await smock.mock("PWNWallet");
			const mockWallet = await mockWalletFactory.deploy();
			await mockWallet.initialize(owner.address, fakeAtr.address);

			await mockWallet.burnAssetTransferRightsToken(332);

			expect(fakeAtr.burnAssetTransferRightsToken).to.have.been.calledOnceWith(332);
		});

	});

});
