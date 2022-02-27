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

});
