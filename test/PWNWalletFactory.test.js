const { expect } = require("chai");
const { ethers } = require("hardhat");
const Iface = require("./sharedIfaces.js");


describe("PWNWalletFactory", function() {

	let Factory;
	let factory;

	before(async function() {
		Factory = await ethers.getContractFactory("PWNWalletFactory");
	});

	beforeEach(async function() {
		factory = await Factory.deploy(ethers.constants.AddressZero);
		await factory.deployed();
	});


	describe("New wallet", function() {

		it("Should deploy new minimal proxy contract", async function() {
			const tx = await factory.newWallet();

			const res = await tx.wait();
			const walletAddr = res.events[1].args.walletAddress;

			const code = await ethers.provider.getCode(walletAddr);
			expect(code).to.match(/^0x363d3d373d3d3d363d73.{40}5af43d82803e903d91602b57fd5bf3/);
		});

		it("Should set new contract address as valid wallet address", async function() {
			const tx = await factory.newWallet();

			const res = await tx.wait();
			const walletAddr = res.events[1].args.walletAddress;

			expect(await factory.isValidWallet(walletAddr)).to.equal(true);
		});

		it("Should call initialize on newly deployed wallet", async function() {
			const tx = await factory.newWallet();

			const res = await tx.wait();
			const wallet = await ethers.getContractAt("PWNWallet", res.events[1].args.walletAddress);

			await expect(
				wallet.initialize(ethers.constants.AddressZero, ethers.constants.AddressZero)
			).to.be.revertedWith("Initializable: contract is already initialized");
		});

		it("Should emit `NewWallet` event", async function() {
			await expect(
				factory.newWallet()
			).to.emit(factory, "NewWallet");
		});

	});


	describe("Is valid wallet", function() {

		it("Should return false when address is not valid wallet", async function() {
			expect(await factory.isValidWallet(factory.address)).to.equal(false);
		});

		it("Should return true when address is not valid wallet", async function() {
			const tx = await factory.newWallet();

			const res = await tx.wait();
			const walletAddr = res.events[1].args.walletAddress;

			expect(await factory.isValidWallet(walletAddr)).to.equal(true);
		});

	});

});
