const chai = require("chai");
const { ethers } = require("hardhat");
const { smock } = require("@defi-wonderland/smock");
const utils = ethers.utils;
const Iface = require("./sharedIfaces.js");
const { deploy1820Registry } = require("../scripts/testDeploy1820Registry.js");
const { CATEGORY } = require("./test-helpers.js");
const { ERC20, ERC721, ERC1155 } = CATEGORY;

const expect = chai.expect;
chai.use(smock.matchers);


describe("PWNWallet", function() {

	let ATR, atr;
	let wallet, walletOther;
	let factory;
	let T20, T721, T1155, T777, T1363;
	let t20, t721, t1155, t777, t1363;
	let owner, other, defaultOperator;

	before(async function() {
		ATR = await ethers.getContractFactory("AssetTransferRights");
		T20 = await ethers.getContractFactory("T20");
		T721 = await ethers.getContractFactory("T721");
		T1155 = await ethers.getContractFactory("T1155");
		T777 = await ethers.getContractFactory("T777");
		T1363 = await ethers.getContractFactory("T1363");

		[owner, other, defaultOperator] = await ethers.getSigners();

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

		t777 = await T777.deploy([]);
		await t777.deployed();

		t1363 = await T1363.deploy();
		await t1363.deployed();

		const walletTx = await factory.connect(owner).newWallet();
		const walletRes = await walletTx.wait();
		wallet = await ethers.getContractAt("PWNWallet", walletRes.events[1].args.walletAddress);

		const walletOtherTx = await factory.connect(other).newWallet();
		const walletOtherRes = await walletOtherTx.wait();
		walletOther = await ethers.getContractAt("PWNWallet", walletOtherRes.events[1].args.walletAddress);
	});


	describe("Execute", function() {

		const tokenId = 123;
		const tokenAmount = 993;

		beforeEach(async function() {
			await t20.mint(wallet.address, tokenAmount);
			await t721.mint(wallet.address, tokenId);
			await t1155.mint(wallet.address, tokenId, tokenAmount);

			await t777.mint(owner.address, tokenAmount);
			await t777.transfer(wallet.address, tokenAmount);

			await t1363.mint(wallet.address, tokenAmount);
		});


		it("Should fail when sender is not wallet owner", async function() {
			await expect(
				wallet.connect(other).execute(
					t721.address,
					Iface.T721.encodeFunctionData("foo", [])
				)
			).to.be.reverted;
		});

		it("Should fail with execution revert message", async function() {
			await expect(
				wallet.execute(
					t721.address,
					Iface.T721.encodeFunctionData("revertWithMessage", [])
				)
			).to.be.revertedWith("50m3 6u5t0m err0r m3ssag3");
		});

		describe("Approvals", function() {

			// Approve without tokenized asset

			it("Should approve ERC20 asset when there is no tokenized asset from collection", async function() {
				await expect(
					wallet.execute(
						t20.address,
						Iface.ERC20.encodeFunctionData("approve", [other.address, tokenAmount])
					)
				).to.not.be.reverted;
			});

			it("Should increase allowance of ERC20 asset when there is no tokenized asset from collection", async function() {
				await expect(
					wallet.execute(
						t20.address,
						Iface.ERC20.encodeFunctionData("increaseAllowance", [other.address, tokenAmount])
					)
				).to.not.be.reverted;
			});

			it("Should decrease allowance of ERC20 asset when there is no tokenized asset from collection", async function() {
				await wallet.execute(
					t20.address,
					Iface.ERC20.encodeFunctionData("approve", [other.address, tokenAmount])
				);

				await expect(
					wallet.execute(
						t20.address,
						Iface.ERC20.encodeFunctionData("decreaseAllowance", [other.address, tokenAmount])
					)
				).to.not.be.reverted;
			});

			it("Should authorize operator of ERC777 asset when there is no tokenized asset from collection", async function() {
				await expect(
					wallet.execute(
						t777.address,
						Iface.ERC777.encodeFunctionData("authorizeOperator", [defaultOperator.address])
					)
				).to.not.be.reverted;
			});

			it("Should revoke operator of ERC777 asset when there is no tokenized asset from collection", async function() {
				await wallet.execute(
					t777.address,
					Iface.ERC777.encodeFunctionData("authorizeOperator", [defaultOperator.address])
				);

				await expect(
					wallet.execute(
						t777.address,
						Iface.ERC777.encodeFunctionData("revokeOperator", [other.address])
					)
				).to.not.be.reverted;
			});

			it("Should approveAndCall ERC1363 asset when there is no tokenized asset from collection", async function() {
				await expect(
					wallet.execute(
						t1363.address,
						Iface.ERC1363.encodeFunctionData("approveAndCall(address,uint256)", [other.address, tokenAmount])
					)
				).to.not.be.reverted;
			});

			it("Should approveAndCall(bytes) ERC1363 asset when there is no tokenized asset from collection", async function() {
				await expect(
					wallet.execute(
						t1363.address,
						Iface.ERC1363.encodeFunctionData("approveAndCall(address,uint256,bytes)", [other.address, tokenAmount, "0x"])
					)
				).to.not.be.reverted;
			});

			it("Should approve ERC721 asset when there is no tokenized asset from collection", async function() {
				await expect(
					wallet.execute(
						t721.address,
						Iface.ERC721.encodeFunctionData("approve", [other.address, tokenId])
					)
				).to.not.be.reverted;
			});

			it("Should approve for all ERC721 asset when there is no tokenized asset from collection", async function() {
				await expect(
					wallet.execute(
						t721.address,
						Iface.ERC721.encodeFunctionData("setApprovalForAll", [other.address, true])
					)
				).to.not.be.reverted;
			});

			it("Should approve for all ERC1155 asset when there is no tokenized asset from collection", async function() {
				await expect(
					wallet.execute(
						t1155.address,
						Iface.ERC1155.encodeFunctionData("setApprovalForAll", [other.address, true])
					)
				).to.not.be.reverted;
			});

			// Try to approve with tokenized asset

			it("Should fail trying to approve ERC20 asset when other asset is tokenized from that collection", async function() {
				await wallet.mintAssetTransferRightsToken([t20.address, ERC20, tokenAmount - 10, 0]);

				await expect(
					wallet.execute(
						t20.address,
						Iface.ERC20.encodeFunctionData("approve", [other.address, 10])
					)
				).to.be.revertedWith("Some asset from collection has transfer right token minted");
			});

			it("Should fail trying to increase allowance of ERC20 asset when other asset is tokenized from that collection", async function() {
				await wallet.mintAssetTransferRightsToken([t20.address, ERC20, tokenAmount - 10, 0]);

				await expect(
					wallet.execute(
						t20.address,
						Iface.ERC20.encodeFunctionData("increaseAllowance", [other.address, 10])
					)
				).to.be.revertedWith("Some asset from collection has transfer right token minted");
			});

			it("Should decrease allowance of ERC20 asset when other asset is tokenized from that collection", async function() {
				await wallet.mintAssetTransferRightsToken([t20.address, ERC20, tokenAmount, 0]);

				await wallet.execute(
					t20.address,
					Iface.ERC20.encodeFunctionData("decreaseAllowance", [other.address, 0])
				);
			});

			it("Should fail trying to authorize operator for ERC777 asset when other asset is tokenized from that collection", async function() {
				await wallet.mintAssetTransferRightsToken([t777.address, ERC20, tokenAmount, 0]);

				await expect(
					wallet.execute(
						t777.address,
						Iface.ERC777.encodeFunctionData("authorizeOperator", [defaultOperator.address])
					)
				).to.be.revertedWith("Some asset from collection has transfer right token minted");
			});

			it("Should revoke operator for ERC777 asset when other asset is tokenized from that collection", async function() {
				await wallet.mintAssetTransferRightsToken([t777.address, ERC20, tokenAmount, 0]);

				await wallet.execute(
					t777.address,
					Iface.ERC777.encodeFunctionData("revokeOperator", [other.address])
				);
			});

			it("Should fail trying to approveAndCall ERC1363 asset when other asset is tokenized from that collection", async function() {
				await wallet.mintAssetTransferRightsToken([t1363.address, ERC20, tokenAmount - 10, 0]);

				await expect(
					wallet.execute(
						t1363.address,
						Iface.ERC1363.encodeFunctionData("approveAndCall(address,uint256)", [other.address, 10])
					)
				).to.be.revertedWith("Some asset from collection has transfer right token minted");
			});

			it("Should fail trying to approveAndCall(bytes) ERC1363 asset when other asset is tokenized from that collection", async function() {
				await wallet.mintAssetTransferRightsToken([t1363.address, ERC20, tokenAmount - 10, 0]);

				await expect(
					wallet.execute(
						t1363.address,
						Iface.ERC1363.encodeFunctionData("approveAndCall(address,uint256,bytes)", [other.address, 10, "0x"])
					)
				).to.be.revertedWith("Some asset from collection has transfer right token minted");
			});

			it("Should fail trying to approve ERC721 asset when other asset is tokenized from that collection", async function() {
				await wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId]);
				await t721.mint(wallet.address, 444);

				await expect(
					wallet.execute(
						t721.address,
						Iface.ERC721.encodeFunctionData("approve", [other.address, 444])
					)
				).to.be.revertedWith("Some asset from collection has transfer right token minted");
			});

			it("Should fail trying to approve for all ERC721 asset when other asset is tokenized from that collection", async function() {
				await wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId]);

				await expect(
					wallet.execute(
						t721.address,
						Iface.ERC721.encodeFunctionData("setApprovalForAll", [other.address, true])
					)
				).to.be.revertedWith("Some asset from collection has transfer right token minted");
			});

			it("Should fail trying to approve for all ERC1155 asset when other asset is tokenized from that collection", async function() {
				await wallet.mintAssetTransferRightsToken([t1155.address, ERC1155, tokenAmount, tokenId]);

				await expect(
					wallet.execute(
						t1155.address,
						Iface.ERC1155.encodeFunctionData("setApprovalForAll", [other.address, true])
					)
				).to.be.revertedWith("Some asset from collection has transfer right token minted");
			});

			// Set / remove operator on approval / revoke

			it("Should update stored operators depending on given / revoked approvals of ERC20 asset", async function() {
				await wallet.execute(
					t20.address,
					Iface.ERC20.encodeFunctionData("approve", [other.address, 1])
				);

				expect(await wallet.hasApprovalsFor(t20.address)).to.equal(true, "ERC20 approval should store operator");

				await wallet.execute(
					t20.address,
					Iface.ERC20.encodeFunctionData("approve", [other.address, 0])
				);

				expect(await wallet.hasApprovalsFor(t20.address)).to.equal(false, "ERC20 approval revoke should remove stored operator");
			});

			it("Should update stored operators depending on allowance increase of ERC20 asset", async function() {
				expect(await wallet.hasApprovalsFor(t20.address)).to.equal(false);

				await wallet.execute(
					t20.address,
					Iface.ERC20.encodeFunctionData("increaseAllowance", [other.address, 10])
				);

				expect(await wallet.hasApprovalsFor(t20.address)).to.equal(true);
			});

			it("Should update stored operators depending on allowance decrease of ERC20 asset", async function() {
				await wallet.execute(
					t20.address,
					Iface.ERC20.encodeFunctionData("approve", [other.address, 1])
				);

				expect(await wallet.hasApprovalsFor(t20.address)).to.equal(true);

				await wallet.execute(
					t20.address,
					Iface.ERC20.encodeFunctionData("decreaseAllowance", [other.address, 1])
				);

				expect(await wallet.hasApprovalsFor(t20.address)).to.equal(false);
			});

			it("Should update stored operators depending on authorized / revoked operator of ERC777 asset", async function() {
				await wallet.execute(
					t777.address,
					Iface.ERC777.encodeFunctionData("authorizeOperator", [defaultOperator.address])
				);

				expect(await wallet.hasApprovalsFor(t777.address)).to.equal(true, "ERC777 authorizeOperator should store operator");

				await wallet.execute(
					t777.address,
					Iface.ERC777.encodeFunctionData("revokeOperator", [defaultOperator.address])
				);

				expect(await wallet.hasApprovalsFor(t777.address)).to.equal(false, "ERC777 revokeOperator should remove stored operator");
			});

			it("Should update stored operators depending on given / revoked approveAndCall of ERC1363 asset", async function() {
				await wallet.execute(
					t1363.address,
					Iface.ERC1363.encodeFunctionData("approveAndCall(address,uint256)", [other.address, 1])
				);

				expect(await wallet.hasApprovalsFor(t1363.address)).to.equal(true, "ERC1363 approval should store operator");

				await wallet.execute(
					t1363.address,
					Iface.ERC1363.encodeFunctionData("approveAndCall(address,uint256)", [other.address, 0])
				);

				expect(await wallet.hasApprovalsFor(t1363.address)).to.equal(false, "ERC1363 approval revoke should remove stored operator");
			});

			it("Should update stored operators depending on given / revoked approveAndCall(bytes) of ERC1363 asset", async function() {
				await wallet.execute(
					t1363.address,
					Iface.ERC1363.encodeFunctionData("approveAndCall(address,uint256,bytes)", [other.address, 1, "0x"])
				);

				expect(await wallet.hasApprovalsFor(t1363.address)).to.equal(true, "ERC1363 approval should store operator");

				await wallet.execute(
					t1363.address,
					Iface.ERC1363.encodeFunctionData("approveAndCall(address,uint256,bytes)", [other.address, 0, "0x"])
				);

				expect(await wallet.hasApprovalsFor(t1363.address)).to.equal(false, "ERC1363 approval revoke should remove stored operator");
			});

			// ERC721 approval is not tracked because operator can approve owners asset without triggering any action on wallet or ATR contract
			// Tracking approvals will not be without leaks thus unusable

			it("Should update stored operators depending on given / revoked approvals of ERC721 asset", async function() {
				await wallet.execute(
					t721.address,
					Iface.ERC721.encodeFunctionData("setApprovalForAll", [other.address, true])
				);

				expect(await wallet.hasApprovalsFor(t721.address)).to.equal(true, "ERC721 approval for all should store operator");

				await wallet.execute(
					t721.address,
					Iface.ERC721.encodeFunctionData("setApprovalForAll", [other.address, false])
				);

				expect(await wallet.hasApprovalsFor(t721.address)).to.equal(false, "ERC721 approval for all revoke should remove stored operator");
			});

			it("Should update stored operators depending on given / revoked approvals of ERC1155 asset", async function() {
				await wallet.execute(
					t1155.address,
					Iface.ERC1155.encodeFunctionData("setApprovalForAll", [other.address, true])
				);

				expect(await wallet.hasApprovalsFor(t1155.address)).to.equal(true, "ERC1155 approval for all should store operator");

				await wallet.execute(
					t1155.address,
					Iface.ERC1155.encodeFunctionData("setApprovalForAll", [other.address, false])
				);

				expect(await wallet.hasApprovalsFor(t1155.address)).to.equal(false, "ERC1155 approval for all revoke should remove stored operator");
			});

		});

		describe("Asset transfers", function() {

			// Not tokenized

			it("Should transfer ERC20 asset when it don't have tokenized transfer rights", async function() {
				await expect(
					wallet.execute(
						t20.address,
						Iface.ERC20.encodeFunctionData("transfer", [other.address, tokenAmount])
					)
				).to.not.be.reverted;
			});

			it("Should transfer ERC777 asset when it don't have tokenized transfer rights", async function() {
				await expect(
					wallet.execute(
						t777.address,
						Iface.ERC20.encodeFunctionData("transfer", [other.address, tokenAmount])
					)
				).to.not.be.reverted;
			});

			it("Should transfer ERC1363 asset when it don't have tokenized transfer rights", async function() {
				await expect(
					wallet.execute(
						t1363.address,
						Iface.ERC20.encodeFunctionData("transfer", [other.address, tokenAmount])
					)
				).to.not.be.reverted;
			});

			it("Should transfer ERC721 asset when it don't have tokenized transfer rights", async function() {
				await expect(
					wallet.execute(
						t721.address,
						Iface.ERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, tokenId])
					)
				).to.not.be.reverted;
			});

			it("Should transfer ERC1155 asset when it don't have tokenized transfer rights", async function() {
				await expect(
					wallet.execute(
						t1155.address,
						Iface.ERC1155.encodeFunctionData("safeTransferFrom", [wallet.address, other.address, tokenId, tokenAmount, "0x"])
					)
				).to.not.be.reverted;
			});

			it("Should call tokenize balance check on ATR contract", async function() {
				const fakeAtr = await smock.fake("AssetTransferRights");
				const mockWalletFactory = await smock.mock("PWNWallet");
				const mockWallet = await mockWalletFactory.deploy();
				await mockWallet.initialize(owner.address, fakeAtr.address);

				await t721.mint(mockWallet.address, 3030);

				await mockWallet.execute(
					t721.address,
					Iface.ERC721.encodeFunctionData("transferFrom", [mockWallet.address, other.address, 3030])
				);

				expect(fakeAtr.checkTokenizedBalance).to.have.been.calledOnce;
			});

			// Tokenized

			it("Should fail when transferring tokenized ERC20 asset", async function() {
				// mint ATR token
				await wallet.mintAssetTransferRightsToken([t20.address, ERC20, tokenAmount, 0]);

				// try to transfer asset as wallet owner
				await expect(
					wallet.execute(
						t20.address,
						Iface.ERC20.encodeFunctionData("transfer", [other.address, 1])
					)
				).to.be.revertedWith("Insufficient tokenized balance");
			});

			it("Should fail when transferring tokenized ERC777 asset", async function() {
				// mint ATR token
				await wallet.mintAssetTransferRightsToken([t777.address, ERC20, tokenAmount, 0]);

				// try to transfer asset as wallet owner
				await expect(
					wallet.execute(
						t777.address,
						Iface.ERC20.encodeFunctionData("transfer", [other.address, 1])
					)
				).to.be.revertedWith("Insufficient tokenized balance");
			});

			it("Should fail when transferring tokenized ERC1363 asset", async function() {
				// mint ATR token
				await wallet.mintAssetTransferRightsToken([t1363.address, ERC20, tokenAmount, 0]);

				// try to transfer asset as wallet owner
				await expect(
					wallet.execute(
						t1363.address,
						Iface.ERC20.encodeFunctionData("transfer", [other.address, 1])
					)
				).to.be.revertedWith("Insufficient tokenized balance");
			});

			it("Should fail when transferring tokenized ERC721 asset", async function() {
				// mint ATR token
				await wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId]);

				// try to transfer asset as wallet owner
				await expect(
					wallet.execute(
						t721.address,
						Iface.ERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, tokenId])
					)
				).to.be.revertedWith("Insufficient tokenized balance");
			});

			it("Should fail when transferring tokenized ERC1155 asset", async function() {
				// mint ATR token
				await wallet.mintAssetTransferRightsToken([t1155.address, ERC1155, tokenAmount, tokenId]);

				// try to transfer asset as wallet owner
				await expect(
					wallet.execute(
						t1155.address,
						Iface.ERC1155.encodeFunctionData("safeTransferFrom", [wallet.address, other.address, tokenId, 1, "0x"])
					)
				).to.be.revertedWith("Insufficient tokenized balance");
			});

			// Tokenized fungible assets

			it("Should transfer untokenized amount of ERC20 asset", async function() {
				// mint ATR token
				await wallet.mintAssetTransferRightsToken([t20.address, ERC20, tokenAmount - 100, 0]);

				// transfer asset as wallet owner
				await expect(
					wallet.execute(
						t20.address,
						Iface.ERC20.encodeFunctionData("transfer", [other.address, 100])
					)
				).to.not.be.reverted;
			});

			it("Should fail when transferring amount biggen than untokenized amount of ERC20 asset", async function() {
				// mint ATR token
				await wallet.mintAssetTransferRightsToken([t20.address, ERC20, tokenAmount - 100, 0]);

				// try to transfer asset as wallet owner
				await expect(
					wallet.execute(
						t20.address,
						Iface.ERC20.encodeFunctionData("transfer", [other.address, 101])
					)
				).to.be.revertedWith("Insufficient tokenized balance");
			});

			it("Should transfer untokenized amount of ERC777 asset", async function() {
				// mint ATR token
				await wallet.mintAssetTransferRightsToken([t777.address, ERC20, tokenAmount - 100, 0]);

				// transfer asset as wallet owner
				await expect(
					wallet.execute(
						t777.address,
						Iface.ERC20.encodeFunctionData("transfer", [other.address, 100])
					)
				).to.not.be.reverted;
			});

			it("Should fail when transferring amount biggen than untokenized amount of ERC777 asset", async function() {
				// mint ATR token
				await wallet.mintAssetTransferRightsToken([t777.address, ERC20, tokenAmount - 100, 0]);

				// try to transfer asset as wallet owner
				await expect(
					wallet.execute(
						t777.address,
						Iface.ERC20.encodeFunctionData("transfer", [other.address, 101])
					)
				).to.be.revertedWith("Insufficient tokenized balance");
			});

			it("Should transfer untokenized amount of ERC1363 asset", async function() {
				// mint ATR token
				await wallet.mintAssetTransferRightsToken([t1363.address, ERC20, tokenAmount - 100, 0]);

				// transfer asset as wallet owner
				await expect(
					wallet.execute(
						t1363.address,
						Iface.ERC20.encodeFunctionData("transfer", [other.address, 100])
					)
				).to.not.be.reverted;
			});

			it("Should fail when transferring amount biggen than untokenized amount of ERC1363 asset", async function() {
				// mint ATR token
				await wallet.mintAssetTransferRightsToken([t1363.address, ERC20, tokenAmount - 100, 0]);

				// try to transfer asset as wallet owner
				await expect(
					wallet.execute(
						t1363.address,
						Iface.ERC20.encodeFunctionData("transfer", [other.address, 101])
					)
				).to.be.revertedWith("Insufficient tokenized balance");
			});

			it("Should transfer untokenized amount of ERC1155 asset", async function() {
				// mint ATR token
				await wallet.mintAssetTransferRightsToken([t1155.address, ERC1155, tokenAmount - 40, tokenId]);

				// transfer asset as wallet owner
				await expect(
					wallet.execute(
						t1155.address,
						Iface.ERC1155.encodeFunctionData("safeTransferFrom", [wallet.address, other.address, tokenId, 40, "0x"])
					)
				).to.not.be.reverted;
			});

			it("Should transfer untokenized token id of ERC1155 asset", async function() {
				await t1155.mint(wallet.address, 45, tokenAmount);

				// mint ATR token
				await wallet.mintAssetTransferRightsToken([t1155.address, ERC1155, tokenAmount, tokenId]);

				// transfer asset as wallet owner
				await expect(
					wallet.execute(
						t1155.address,
						Iface.ERC1155.encodeFunctionData("safeTransferFrom", [wallet.address, other.address, 45, tokenAmount, "0x"])
					)
				).to.not.be.reverted;
			});

			it("Should fail when transferring amount biggen than untokenized amount of ERC1155 asset", async function() {
				// mint ATR token
				await wallet.mintAssetTransferRightsToken([t1155.address, ERC1155, tokenAmount - 40, tokenId]);

				// transfer asset as wallet owner
				await expect(
					wallet.execute(
						t1155.address,
						Iface.ERC1155.encodeFunctionData("safeTransferFrom", [wallet.address, other.address, tokenId, 41, "0x"])
					)
				).to.be.revertedWith("Insufficient tokenized balance");
			});

		});

	});


	describe("Mint ATR token", function() {

		it("Should fail when sender is not wallet owner", async function() {
			await expect(
				wallet.connect(other).mintAssetTransferRightsToken([t721.address, ERC721, 1, 40])
			).to.be.reverted;
		});

		it("Should call mint on ATR contract", async function() {
			const fakeAtr = await smock.fake("AssetTransferRights");
			const mockWalletFactory = await smock.mock("PWNWallet");
			const mockWallet = await mockWalletFactory.deploy();
			await mockWallet.initialize(owner.address, fakeAtr.address);

			await mockWallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, 40]);

			expect(fakeAtr.mintAssetTransferRightsToken).to.have.been.calledOnceWith([t721.address, ERC721, 1, 40]);
		});

	});


	describe("Burn ATR token", function() {

		it("Should fail when sender is not wallet owner", async function() {
			await expect(
				wallet.connect(other).burnAssetTransferRightsToken(332)
			).to.be.reverted;
		});

		it("Should call burn on ATR contract", async function() {
			const fakeAtr = await smock.fake("AssetTransferRights");
			const mockWalletFactory = await smock.mock("PWNWallet");
			const mockWallet = await mockWalletFactory.deploy();
			await mockWallet.initialize(owner.address, fakeAtr.address);

			await mockWallet.burnAssetTransferRightsToken(332);

			expect(fakeAtr.burnAssetTransferRightsToken).to.have.been.calledOnceWith(332);
		});

	});


	describe("Transfer asset from", function() {

		it("Should fail when sender is not wallet owner", async function() {
			await expect(
				wallet.connect(other).transferAssetFrom(ethers.constants.AddressZero, 0, true)
			).to.be.reverted;
		});

		it("Should call transfer asset from on ATR contract", async function() {
			const fakeAtr = await smock.fake("AssetTransferRights");
			const mockWalletFactory = await smock.mock("PWNWallet");
			const mockWallet = await mockWalletFactory.deploy();
			await mockWallet.initialize(owner.address, fakeAtr.address);

			await mockWallet.transferAssetFrom(ethers.constants.AddressZero, 0, true);

			expect(fakeAtr.transferAssetFrom).to.have.been.calledOnceWith(ethers.constants.AddressZero, 0, true);
		});

	});


	describe("Resolve invalid approval", function() {

		it("Should resolve invalid approval when ERC20 asset was transferred by approved address", async function() {
			// Mint ERC20 asset to wallet
			await t20.mint(wallet.address, 1000);

			// Approve ERC20 asset
			await wallet.execute(
				t20.address,
				Iface.ERC20.encodeFunctionData("approve", [other.address, 322])
			);

			// Transfer asset by approved address
			await t20.connect(other).transferFrom(wallet.address, other.address, 322);

			// Check that internal state is corrupted
			expect(
				await wallet.hasApprovalsFor(t20.address)
			).to.equal(true);

			// Fix corrupted internal state
			await wallet.resolveInvalidApproval(t20.address, other.address);

			// Check that internal state is fixed
			expect(
				await wallet.hasApprovalsFor(t20.address)
			).to.equal(false);
		});

	});


	describe("Transfer asset", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await t721.mint(wallet.address, tokenId);

			// ATR token with id 1
			await wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId]);
		});


		it("Should fail when sender is not ATR contract", async function() {
			await expect(
				wallet.transferAsset([t721.address, ERC721, 1, 1], walletOther.address)
			).to.be.revertedWith("Caller is not asset transfer rights contract");
		});

		it("Should transfer asset to receiver as ERC20", async function() {
			const fakeToken = await smock.fake("T20");
			const mockWalletFactory = await smock.mock("PWNWallet");
			const mockWallet = await mockWalletFactory.deploy();
			await mockWallet.initialize(owner.address, other.address);

			await mockWallet.connect(other).transferAsset([fakeToken.address, ERC20, 1, 1], walletOther.address);

			expect(fakeToken.transfer).to.have.been.calledOnce;
		});

		it("Should transfer asset to receiver as ERC777", async function() {
			const fakeToken = await smock.fake("T777");
			const mockWalletFactory = await smock.mock("PWNWallet");
			const mockWallet = await mockWalletFactory.deploy();
			await mockWallet.initialize(owner.address, other.address);

			await mockWallet.connect(other).transferAsset([fakeToken.address, ERC20, 1, 1], walletOther.address);

			expect(fakeToken.transfer).to.have.been.calledOnce;
		});

		it("Should transfer asset to receiver as ERC1363", async function() {
			const fakeToken = await smock.fake("T1363");
			const mockWalletFactory = await smock.mock("PWNWallet");
			const mockWallet = await mockWalletFactory.deploy();
			await mockWallet.initialize(owner.address, other.address);

			await mockWallet.connect(other).transferAsset([fakeToken.address, ERC20, 1, 1], walletOther.address);

			expect(fakeToken.transfer).to.have.been.calledOnce;
		});

		it("Should transfer asset to receiver as ERC721", async function() {
			const fakeToken = await smock.fake("T721");
			const mockWalletFactory = await smock.mock("PWNWallet");
			const mockWallet = await mockWalletFactory.deploy();
			await mockWallet.initialize(owner.address, other.address);

			await mockWallet.connect(other).transferAsset([fakeToken.address, ERC721, 1, 1], walletOther.address);

			expect(fakeToken["safeTransferFrom(address,address,uint256)"]).to.have.been.calledOnce;
		});

		it("Should transfer asset to receiver as ERC1155", async function() {
			const fakeToken = await smock.fake("T1155");
			const mockWalletFactory = await smock.mock("PWNWallet");
			const mockWallet = await mockWalletFactory.deploy();
			await mockWallet.initialize(owner.address, other.address);

			await mockWallet.connect(other).transferAsset([fakeToken.address, ERC1155, 1, 1], walletOther.address);

			expect(fakeToken.safeTransferFrom).to.have.been.calledOnce;
		});

	});


	describe("Has operators for", function() {

		it("Should return true if collection has at least one operator stored", async function() {
			await wallet.execute(
				t1155.address,
				Iface.ERC1155.encodeFunctionData("setApprovalForAll", [other.address, true])
			);

			expect(await wallet.hasApprovalsFor(t1155.address)).to.equal(true);
		});

		it("Should return true if token has default operator", async function() {
			t777 = await T777.deploy([defaultOperator.address]);
			await t777.deployed();

			expect(await wallet.hasApprovalsFor(t777.address)).to.equal(true);
		});

		it("Should return false if collection has no operator stored", async function() {
			await t1155.mint(wallet.address, 14, 332);

			expect(await wallet.hasApprovalsFor(t1155.address)).to.equal(false);
		});

	});


	describe("IERC721Receiver", function() {

		it("Should return onERC721Received function selector", async function() {
			const response = await wallet.onERC721Received(other.address, other.address, 1, "0x");

			expect(response).to.equal("0x150b7a02");
		});

	});


	describe("IERC1155Receiver", function() {

		it("Should return onERC1155Received function selector", async function() {
			const response = await wallet.onERC1155Received(other.address, other.address, 1, 1, "0x");

			expect(response).to.equal("0xf23a6e61");
		});

		it("Should return onERC1155BatchReceived function selector", async function() {
			const response = await wallet.onERC1155BatchReceived(other.address, other.address, [1], [1], "0x");

			expect(response).to.equal("0xbc197c81");
		});

	});


	describe("Supports interface", function() {

		function funcSelector(signature) {
			const bytes = utils.toUtf8Bytes(signature)
			const hash = utils.keccak256(bytes);
			const selector = utils.hexDataSlice(hash, 0, 4);
			return ethers.BigNumber.from(selector);
		}

		it("Should support IPWNWallet interface", async function() {
			const interfaceId = funcSelector("transferAsset((address,uint8,uint256,uint256),address)")
				.xor(funcSelector("hasApprovalsFor(address)"));

			expect(await wallet.supportsInterface(interfaceId)).to.equal(true);
		});

		it("Should support IERC721Receiver interface", async function() {
			const interfaceId = funcSelector("onERC721Received(address,address,uint256,bytes)");

			expect(await wallet.supportsInterface(interfaceId)).to.equal(true);
		});

		it("Should support IERC1155Receiver interface", async function() {
			const interfaceId = funcSelector("onERC1155Received(address,address,uint256,uint256,bytes)")
				.xor(funcSelector("onERC1155BatchReceived(address,address,uint256[],uint256[],bytes)"));

			expect(await wallet.supportsInterface(interfaceId)).to.equal(true);
		});

		it("Should support IERC165 interface", async function() {
			const interfaceId = funcSelector("supportsInterface(bytes4)");

			expect(await wallet.supportsInterface(interfaceId)).to.equal(true);
		});

	});

});
