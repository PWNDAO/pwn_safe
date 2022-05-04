const { expect } = require("chai");
const { ethers } = require("hardhat");
const Iface = require("./sharedIfaces.js");
const { deploy1820Registry } = require("../scripts/testDeploy1820Registry.js");
const { CATEGORY } = require("./test-helpers.js");
const { ERC20, ERC721, ERC1155 } = CATEGORY;


describe("Use cases", function() {

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

		t20 = await T20.deploy();
		await t20.deployed();

		t721 = await T721.deploy();
		await t721.deployed();

		t1155 = await T1155.deploy();
		await t1155.deployed();

		const walletTx = await factory.connect(owner).newWallet();
		const walletRes = await walletTx.wait();
		wallet = await ethers.getContractAt("PWNWallet", walletRes.events[1].args.walletAddress);

		const walletOtherTx = await factory.connect(other).newWallet();
		const walletOtherRes = await walletOtherTx.wait();
		walletOther = await ethers.getContractAt("PWNWallet", walletOtherRes.events[1].args.walletAddress);
	});


	describe("ERC20", function() {

		/**
		 * 1:  mint asset
		 * 2:  approve 1/3 to first address
		 * 3:  approve 1/3 to second address
		 * 4:  fail to mint ATR token for 1/3
		 * 5:  first address transfers asset
		 * 6:  resolve internal state
		 * 7:  fail to mint ATR token for 1/3
		 * 8:  set approvel of second address to 0
		 * 9:  mint ATR token for 1/3
		 * 10: fail to approve asset
		 */
		it("UC:ERC20:1", async function() {
			// 1:
			await t20.mint(wallet.address, 900);

			// 2:
			await wallet.execute(
				t20.address,
				Iface.ERC20.encodeFunctionData("approve", [addr1.address, 300])
			);

			// 3:
			await wallet.execute(
				t20.address,
				Iface.ERC20.encodeFunctionData("approve", [addr2.address, 300])
			);

			// 4:
			await expect(
				wallet.mintAssetTransferRightsToken([t20.address, ERC20, 300, 0])
			).to.be.reverted;

			// 5:
			await t20.connect(addr1).transferFrom(wallet.address, addr1.address, 300);

			// 6:
			await wallet.resolveInvalidApproval(t20.address, addr1.address);

			// 7:
			await expect(
				wallet.mintAssetTransferRightsToken([t20.address, ERC20, 300, 0])
			).to.be.reverted;

			// 8:
			await wallet.execute(
				t20.address,
				Iface.ERC20.encodeFunctionData("approve", [addr2.address, 0])
			);

			// 9:
			await wallet.mintAssetTransferRightsToken([t20.address, ERC20, 300, 0]);

			// 10:
			await expect(
				wallet.execute(
					t20.address,
					Iface.ERC20.encodeFunctionData("approve", [addr2.address, 300])
				)
			).to.be.reverted;
		});

		/**
		 * 1:  mint asset
		 * 2:  mint ATR token for 1/3
		 * 3:  fail to approve asset
		 * 4:  transfer ATR token to other wallet
		 * 5:  transfer asset via ATR token
		 * 6:  approve 1/3 to first address
		 * 7:  transfer ATR token back to wallet
		 * 8:  fail to transfer tokenized asset back via ATR token
		 * 9:  first address transfers asset
		 * 10: resolve internal state
		 * 11: transfer tokenized asset back via ATR token
		 */
		it("UC:ERC20:2", async function() {
			// 1:
			await t20.mint(wallet.address, 900);

			// 2:
			await wallet.mintAssetTransferRightsToken([t20.address, ERC20, 300, 0]);

			// 3:
			await expect(
				wallet.execute(
					t20.address,
					Iface.ERC20.encodeFunctionData("approve", [addr1.address, 300])
				)
			).to.be.reverted;

			// 4:
			await wallet.execute(
				atr.address,
				Iface.ERC721.encodeFunctionData("transferFrom", [wallet.address, walletOther.address, 1])
			);

			// 5:
			await walletOther.connect(other).execute(
				atr.address,
				Iface.ATR.encodeFunctionData("transferAssetFrom", [wallet.address, 1, false])
			);

			// 6:
			await wallet.execute(
				t20.address,
				Iface.ERC20.encodeFunctionData("approve", [addr1.address, 300])
			);

			// 7:
			await walletOther.connect(other).execute(
				atr.address,
				Iface.ERC721.encodeFunctionData("transferFrom", [walletOther.address, wallet.address, 1])
			);

			// 8:
			await expect(
				wallet.execute(
					atr.address,
					Iface.ATR.encodeFunctionData("transferAssetFrom", [walletOther.address, 1, false])
				)
			).to.be.reverted;

			// 9:
			await t20.connect(addr1).transferFrom(wallet.address, addr1.address, 300);

			// 10:
			await wallet.resolveInvalidApproval(t20.address, addr1.address);

			// 11:
			await wallet.execute(
				atr.address,
				Iface.ATR.encodeFunctionData("transferAssetFrom", [walletOther.address, 1, false])
			);
		});

		/**
		 * 1: mint asset
		 * 2: mint ATR token for 1/3
		 * 3: burn 1/2 of assets
		 * 4: fail to burn 1/2 of assets
		 * 5: burn ATR token fo 1/3
		 * 6: burn 1/2 of assets
		 */
		it("UC:ERC20:3", async function() {
			// 1:
			await t20.mint(wallet.address, 600);

			// 2:
			await wallet.mintAssetTransferRightsToken([t20.address, ERC20, 200, 0]);

			// 3:
			await wallet.execute(
				t20.address,
				Iface.T20.encodeFunctionData("burn", [wallet.address, 300])
			);

			// 4:
			await expect(
				wallet.execute(
					t20.address,
					Iface.T20.encodeFunctionData("burn", [wallet.address, 300])
				)
			).to.be.reverted;

			// 5:
			await wallet.burnAssetTransferRightsToken(1);

			// 6:
			await t20.burn(wallet.address, 300);
		});

	});


	describe("ERC721", function() {

		/**
		 * 1:  mint asset 1
		 * 2:  approve asset 1 to first address
		 * 3:  mint asset 2
		 * 4:  mint asset 3
		 * 5:  mint ATR token for asset 2
		 * 6:  fail to mint ATR token for asset 1
		 * 7:  fail to approve asset 3
		 * 8:  set second address as wallets operator for ATR tokens
		 * 9:  second address transfers ATR token 1 to it
		 * 10: fail to transfer tokenized asset 2 via ATR token 1 to second address without burning ATR token
		 * 11: transfer tokenized asset 2 via ATR token 1 to second address and burn ATR token
		 * 12: approve asset 3 to first address
		 */
		it("UC:ERC721:1", async function() {
			// 1:
			await t721.mint(wallet.address, 1);

			// 2:
			await wallet.execute(
				t721.address,
				Iface.ERC721.encodeFunctionData("approve", [addr1.address, 1])
			);

			// 3:
			await t721.mint(wallet.address, 2);

			// 4:
			await t721.mint(wallet.address, 3);

			// 5:
			await wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, 2]);

			// 6:
			await expect(
				wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, 1])
			).to.be.reverted;

			// 7:
			await expect(
				wallet.execute(
					t721.address,
					Iface.ERC721.encodeFunctionData("approve", [addr1.address, 3])
				)
			).to.be.reverted;

			// 8:
			await wallet.execute(
				atr.address,
				Iface.ERC721.encodeFunctionData("setApprovalForAll", [addr2.address, true])
			);

			// 9:
			await atr.connect(addr2).transferFrom(wallet.address, addr2.address, 1);

			// 10:
			await expect(
				atr.connect(addr2).transferAssetFrom(wallet.address, 1, false)
			).to.be.reverted;

			// 11:
			await atr.connect(addr2).transferAssetFrom(wallet.address, 1, true);

			// 12:
			await wallet.execute(
				t721.address,
				Iface.ERC721.encodeFunctionData("approve", [addr1.address, 3])
			);
		});

		/**
		 * 1:  mint asset id 1
		 * 2:  mint asset id 2
		 * 3:  set first address as wallet operator for asset
		 * 4:  fail to mint ATR token for asset id 1
		 * 5:  remove first address as wallet operator for asset
		 * 6:  mint ATR token 1 for asset id 1
		 * 7:  fail to set first address as wallet operator for asset
		 * 8:  transfer ATR token 1 to first address
		 * 9:  transfer tokenized asset id 1 to first address and burn ATR token
		 * 10: set first address as wallet operator for asset
		 */
		it("UC:ERC721:2", async function() {
			// 1:
			await t721.mint(wallet.address, 1);

			// 2:
			await t721.mint(wallet.address, 2);

			// 3:
			await wallet.execute(
				t721.address,
				Iface.ERC721.encodeFunctionData("setApprovalForAll", [addr1.address, true])
			);

			// 4:
			await expect(
				wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, 1])
			).to.be.reverted;

			// 5:
			await wallet.execute(
				t721.address,
				Iface.ERC721.encodeFunctionData("setApprovalForAll", [addr1.address, false])
			);

			// 6:
			await wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, 1]);

			// 7:
			await expect(
				wallet.execute(
					t721.address,
					Iface.ERC721.encodeFunctionData("setApprovalForAll", [addr1.address, false])
				)
			).to.be.reverted;

			// 8:
			await wallet.execute(
				atr.address,
				Iface.ERC721.encodeFunctionData("transferFrom", [wallet.address, addr1.address, 1])
			);

			// 9:
			await atr.connect(addr1).transferAssetFrom(wallet.address, 1, true);

			// 10:
			await wallet.execute(
				t721.address,
				Iface.ERC721.encodeFunctionData("setApprovalForAll", [addr1.address, false])
			);
		});

	});


	describe("ERC1155", function() {

		/**
		 * 1:  mint asset id 1 amount 600
		 * 2:  mint asset id 2 amount 100
		 * 3:  set first address as wallet operator for asset
		 * 4:  fail to mint ATR token for asset id 1 amount 600
		 * 5:  remove first address as wallet operator for asset
		 * 6:  mint ATR token 1 for asset id 1 amount 600
		 * 7:  fail to set first address as wallet operator for asset
		 * 8:  transfer ATR token 1 to first address
		 * 9:  transfer tokenized asset id 1 amount 600 to first address and burn ATR token
		 * 10: set first address as wallet operator for asset
		 */
		it("UC:ERC1155:1", async function() {
			// 1:
			await t1155.mint(wallet.address, 1, 600);

			// 2:
			await t1155.mint(wallet.address, 2, 100);

			// 3:
			await wallet.execute(
				t1155.address,
				Iface.ERC1155.encodeFunctionData("setApprovalForAll", [addr1.address, true])
			);

			// 4:
			await expect(
				wallet.mintAssetTransferRightsToken([t1155.address, ERC1155, 600, 1])
			).to.be.reverted;

			// 5:
			await wallet.execute(
				t1155.address,
				Iface.ERC1155.encodeFunctionData("setApprovalForAll", [addr1.address, false])
			);

			// 6:
			await wallet.mintAssetTransferRightsToken([t1155.address, ERC1155, 600, 1]);

			// 7:
			await expect(
				wallet.execute(
					t1155.address,
					Iface.ERC1155.encodeFunctionData("setApprovalForAll", [addr1.address, false])
				)
			).to.be.reverted;

			// 8:
			await wallet.execute(
				atr.address,
				Iface.ERC721.encodeFunctionData("transferFrom", [wallet.address, addr1.address, 1])
			);

			// 9:
			await atr.connect(addr1).transferAssetFrom(wallet.address, 1, true);

			// 10:
			await wallet.execute(
				t1155.address,
				Iface.ERC1155.encodeFunctionData("setApprovalForAll", [addr1.address, false])
			);
		});

	});

});
