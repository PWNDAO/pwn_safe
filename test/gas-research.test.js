const { expect } = require("chai");
const { ethers } = require("hardhat");
const Iface = require("./sharedIfaces.js");
const { deploy1820Registry } = require("../scripts/testDeploy1820Registry.js");


function printGasCosts(gasCosts) {
	console.log(gasCosts.join("\n"));
	// console.log([gasCosts[0], gasCosts[1], gasCosts[2], gasCosts[3], gasCosts[5], gasCosts[10], gasCosts[20], gasCosts[30], gasCosts[50], gasCosts[100]].join("\n"));
}

describe("Gas research", function() {

	let ATR, atr;
	let wallet, walletOther;
	let factory;
	let T20, T721, T1155;
	let t20, t721, t1155;
	let owner, other;

	before(async function() {
		ATR = await ethers.getContractFactory("AssetTransferRights");
		T20 = await ethers.getContractFactory("T20");
		T721 = await ethers.getContractFactory("T721");
		T1155 = await ethers.getContractFactory("T1155");

		[owner, other, addr1, addr2] = await ethers.getSigners();

		await deploy1820Registry(other);
	});

	beforeEach(async function() {
		atr = await ATR.deploy();
		await atr.deployed();

		factory = await ethers.getContractAt("PWNWalletFactory", atr.walletFactory());

		const walletTx = await factory.connect(owner).newWallet();
		const walletRes = await walletTx.wait();
		wallet = await ethers.getContractAt("PWNWallet", walletRes.events[1].args.walletAddress);
	});


	describe("Mint new ATR token", function() {

		it("mint ERC20", async function() {
			t20 = await T20.deploy();
			await t20.deployed();

			let gasCosts = [];

			const maxValue = 100;
			for (let i = 0; i <= maxValue; i++) {
				await t20.mint(wallet.address, 10);
				const tx = await wallet.mintAssetTransferRightsToken([t20.address, 0, 10, 0]);
				const res = await tx.wait();

				gasCosts.push(res.gasUsed.toNumber());
			}

			printGasCosts(gasCosts);
		});

		it("mint ERC721", async function() {
			t721 = await T721.deploy();
			await t721.deployed();

			let gasCosts = [];

			const maxValue = 100;
			for (let i = 0; i <= maxValue; i++) {
				await t721.mint(wallet.address, i);
				const tx = await wallet.mintAssetTransferRightsToken([t721.address, 1, 1, i]);
				const res = await tx.wait();

				gasCosts.push(res.gasUsed.toNumber());
			}

			printGasCosts(gasCosts);
		});

		it("mint ERC1155 fungible", async function() {
			t1155 = await T1155.deploy();
			await t1155.deployed();

			let gasCosts = [];

			const maxValue = 100;
			for (let i = 0; i <= maxValue; i++) {
				await t1155.mint(wallet.address, 1, 10);
				const tx = await wallet.mintAssetTransferRightsToken([t1155.address, 2, 10, 1]);
				const res = await tx.wait();

				gasCosts.push(res.gasUsed.toNumber());
			}

			printGasCosts(gasCosts);
		});

		it("mint ERC1155 nft", async function() {
			t1155 = await T1155.deploy();
			await t1155.deployed();

			let gasCosts = [];

			const maxValue = 100;
			for (let i = 0; i <= maxValue; i++) {
				await t1155.mint(wallet.address, i, 10);
				const tx = await wallet.mintAssetTransferRightsToken([t1155.address, 2, 10, i]);
				const res = await tx.wait();

				gasCosts.push(res.gasUsed.toNumber());
			}

			printGasCosts(gasCosts);
		});

	});


	describe("Transfer asset", function() {

		it("transfer ERC20", async function() {
			this.timeout(100_000);

			t20 = await T20.deploy();
			await t20.deployed();

			let gasCosts = [];

			const maxValue = 100;
			for (let i = 0; i <= maxValue; i++) {
				await t20.mint(wallet.address, 10);
				await wallet.mintAssetTransferRightsToken([t20.address, 0, 10, 0]);


				const tx = await wallet.execute(
					atr.address,
					Iface.ERC721.encodeFunctionData("transferFrom", [wallet.address, addr1.address, i + 1])
				);
				const res = await tx.wait();

				gasCosts.push(res.gasUsed.toNumber());

				await atr.connect(addr1).transferFrom(addr1.address, wallet.address, i + 1);
			}

			printGasCosts(gasCosts);
		});

		it("transfer ERC721", async function() {
			this.timeout(1_000_000);

			t721 = await T721.deploy();
			await t721.deployed();

			let gasCosts = [];

			const maxValue = 100;
			for (let i = 0; i <= maxValue; i++) {
				await t721.mint(wallet.address, i);
				await wallet.mintAssetTransferRightsToken([t721.address, 1, 1, i]);


				const tx = await wallet.execute(
					atr.address,
					Iface.ERC721.encodeFunctionData("transferFrom", [wallet.address, addr1.address, i + 1])
				);
				const res = await tx.wait();

				gasCosts.push(res.gasUsed.toNumber());

				await atr.connect(addr1).transferFrom(addr1.address, wallet.address, i + 1);
			}

			printGasCosts(gasCosts);
		});

		it("transfer ERC1155 fungible", async function() {
			this.timeout(100_000);

			t1155 = await T1155.deploy();
			await t1155.deployed();

			let gasCosts = [];

			const maxValue = 100;
			for (let i = 0; i <= maxValue; i++) {
				await t1155.mint(wallet.address, 1, 10);
				await wallet.mintAssetTransferRightsToken([t1155.address, 2, 10, 1]);


				const tx = await wallet.execute(
					atr.address,
					Iface.ERC721.encodeFunctionData("transferFrom", [wallet.address, addr1.address, i + 1])
				);
				const res = await tx.wait();

				gasCosts.push(res.gasUsed.toNumber());

				await atr.connect(addr1).transferFrom(addr1.address, wallet.address, i + 1);
			}

			printGasCosts(gasCosts);
		});

		it("transfer ERC1155 nft", async function() {
			this.timeout(1_000_000);

			t1155 = await T1155.deploy();
			await t1155.deployed();

			let gasCosts = [];

			const maxValue = 100;
			for (let i = 0; i <= maxValue; i++) {
				await t1155.mint(wallet.address, i, 10);
				await wallet.mintAssetTransferRightsToken([t1155.address, 2, 10, i]);


				const tx = await wallet.execute(
					atr.address,
					Iface.ERC721.encodeFunctionData("transferFrom", [wallet.address, addr1.address, i + 1])
				);
				const res = await tx.wait();

				gasCosts.push(res.gasUsed.toNumber());

				await atr.connect(addr1).transferFrom(addr1.address, wallet.address, i + 1);
			}

			printGasCosts(gasCosts);
		});

	});

});
