const chai = require("chai");
const { ethers } = require("hardhat");
const { smock } = require("@defi-wonderland/smock");
const utils = ethers.utils;
const Iface = require("./sharedIfaces.js");
const { deploy1820Registry } = require("../scripts/testDeploy1820Registry.js");

const expect = chai.expect;
chai.use(smock.matchers);


describe("AssetTransferRights", function() {

	let ATR, atr;
	let wallet, walletOther, walletEmpty;
	let factory;
	let T20, T721, T1155;
	let t20, t721, t1155;
	let owner, other;

	before(async function() {
		ATR = await ethers.getContractFactory("AssetTransferRights");
		T20 = await ethers.getContractFactory("T20");
		T721 = await ethers.getContractFactory("T721");
		T1155 = await ethers.getContractFactory("T1155");

		[owner, other] = await ethers.getSigners();

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

		const walletEmptyTx = await factory.connect(other).newWallet();
		const walletEmptyRes = await walletEmptyTx.wait();
		walletEmpty = await ethers.getContractAt("PWNWallet", walletEmptyRes.events[1].args.walletAddress);
	});


	describe("Mint", function() {

		const tokenId = 123;
		const tokenAmount = 3323;

		beforeEach(async function() {
			await t20.mint(wallet.address, tokenAmount);
			await t721.mint(wallet.address, tokenId);
			await t1155.mint(wallet.address, tokenId, tokenAmount);
		});


		it("Should fail when sender is not PWN Wallet", async function() {
			await t721.mint(other.address, 333);

			await expect(
				atr.connect(other).mintAssetTransferRightsToken([t721.address, 1, 1, 333])
			).to.be.revertedWith("Caller is not a PWN Wallet");
		});

		it("Should fail when sender is not asset owner", async function() {
			await t721.mint(owner.address, 3232);

			await expect(
				wallet.mintAssetTransferRightsToken([t721.address, 1, 1, 3232])
			).to.be.revertedWith("Insufficient balance to tokenize");
		});

		it("Should fail when trying to tokenize zero address asset", async function() {
			await expect(
				wallet.mintAssetTransferRightsToken([ethers.constants.AddressZero, 1, 1, 3232])
			).to.be.revertedWith("Attempting to tokenize zero address asset");
		});

		it("Should fail when trying to tokenize ATR token", async function() {
			await expect(
				wallet.mintAssetTransferRightsToken([atr.address, 1, 1, 3232])
			).to.be.revertedWith("Attempting to tokenize ATR token");
		});

		it("Should fail when asset is invalid", async function() {
			await expect(
				wallet.mintAssetTransferRightsToken([t721.address, 1, 0, tokenId])
			).to.be.revertedWith("MultiToken.Asset is not valid");
		});

		it("Should fail when ERC721 asset is approved", async function() {
			await wallet.execute(
				t721.address,
				Iface.ERC721.encodeFunctionData("approve", [owner.address, tokenId])
			);

			await expect(
				wallet.mintAssetTransferRightsToken([t721.address, 1, 1, tokenId])
			).to.be.revertedWith("Tokenized asset has an approved address");
		});

		describe("Asset category", function() {

			describe("Asset implementing ERC165", function() {

				it("Should fail when passing ERC20 asset with ERC721 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t20.address, 1, 1, 132])
					).to.be.revertedWith("Invalid provided category");
				});

				it("Should fail when passing ERC20 asset with ERC1155 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t20.address, 2, tokenAmount, 0])
					).to.be.revertedWith("Invalid provided category");
				});

				it("Should fail when passing ERC721 asset with ERC20 category", async function() {
					await t721.mint(wallet.address, 0);

					await expect(
						wallet.mintAssetTransferRightsToken([t721.address, 0, 1, 0])
					).to.be.revertedWith("Invalid provided category");
				});

				it("Should fail when passing ERC721 asset with ERC1155 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t721.address, 2, 1, tokenId])
					).to.be.revertedWith("Invalid provided category");
				});

				it("Should fail when passing ERC1155 asset with ERC20 category", async function() {
					await t1155.mint(wallet.address, 0, tokenAmount);

					await expect(
						wallet.mintAssetTransferRightsToken([t1155.address, 0, tokenAmount, 0])
					).to.be.revertedWith("Invalid provided category");
				});

				it("Should fail when passing ERC1155 asset with ERC721 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t1155.address, 1, 1, tokenId])
					).to.be.revertedWith("Invalid provided category");
				});

				it("Should mint ATR token for ERC20 asset with ERC20 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t20.address, 0, tokenAmount, 0])
					).to.not.be.reverted;
				});

				it("Should mint ATR token for ERC721 asset with ERC721 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t721.address, 1, 1, tokenId])
					).to.not.be.reverted;
				});

				it("Should mint ATR token for ERC1155 asset with ERC1155 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t1155.address, 2, tokenAmount, tokenId])
					).to.not.be.reverted;
				});

			});

			describe("Asset not implementing ERC165", function() {

				beforeEach(async function() {
					await t20.supportERC165(false);
					await t721.supportERC165(false);
					await t1155.supportERC165(false);
				});


				it("Should fail when passing ERC20 asset with ERC721 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t20.address, 1, 1, 132])
					).to.be.reverted;
				});

				it("Should fail when passing ERC20 asset with ERC1155 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t20.address, 2, tokenAmount, 0])
					).to.be.reverted;
				});

				it("Should fail when passing ERC721 asset with ERC20 category", async function() {
					await t721.mint(wallet.address, 0);

					await expect(
						wallet.mintAssetTransferRightsToken([t721.address, 0, 1, 0])
					).to.be.revertedWith("Invalid provided category");
				});

				it("Should fail when passing ERC721 asset with ERC1155 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t721.address, 2, 1, tokenId])
					).to.be.reverted;
				});

				it("Should fail when passing ERC1155 asset with ERC20 category", async function() {
					await t1155.mint(wallet.address, 0, tokenAmount);

					await expect(
						wallet.mintAssetTransferRightsToken([t1155.address, 0, tokenAmount, 0])
					).to.be.reverted;
				});

				it("Should fail when passing ERC1155 asset with ERC721 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t1155.address, 1, 1, tokenId])
					).to.be.reverted;
				});

				it("Should mint ATR token for ERC20 asset with ERC20 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t20.address, 0, tokenAmount, 0])
					).to.not.be.reverted;
				});

				it("Should fail when passing ERC721 which doesn't implement ERC165", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t721.address, 1, 1, tokenId])
					).to.be.revertedWith("Invalid provided category");
				});

				it("Should fail when passing ERC1155 which doesn't implement ERC165", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t1155.address, 2, tokenAmount, tokenId])
					).to.be.revertedWith("Invalid provided category");
				});

			});

		});

		it("Should fail when ERC20 asset doesn't have enough untokenized balance to tokenize without any tokenized asset", async function() {
			await expect(
				wallet.mintAssetTransferRightsToken([t20.address, 0, tokenAmount + 1, 0])
			).to.be.revertedWith("Insufficient balance to tokenize");
		});

		it("Should fail when ERC1155 asset doesn't have enough untokenized balance to tokenize without any tokenized asset", async function() {
			await expect(
				wallet.mintAssetTransferRightsToken([t1155.address, 2, tokenAmount + 1, tokenId])
			).to.be.revertedWith("Insufficient balance to tokenize");
		});

		it("Should fail when ERC20 asset doesn't have enough untokenized balance to tokenize with some tokenized asset", async function() {
			await wallet.mintAssetTransferRightsToken([t20.address, 0, tokenAmount - 20, 0]);

			await expect(
				wallet.mintAssetTransferRightsToken([t20.address, 0, 21, 0])
			).to.be.revertedWith("Insufficient balance to tokenize");
		});

		it("Should fail when ERC721 asset is already tokenised", async function() {
			await wallet.mintAssetTransferRightsToken([t721.address, 1, 1, tokenId]);

			await expect(
				wallet.mintAssetTransferRightsToken([t721.address, 1, 1, tokenId])
			).to.be.revertedWith("Insufficient balance to tokenize");
		});

		it("Should fail when ERC1155 asset doesn't have enough untokenized balance to tokenize with some tokenized asset", async function() {
			await wallet.mintAssetTransferRightsToken([t1155.address, 2, tokenAmount - 20, tokenId]);

			await expect(
				wallet.mintAssetTransferRightsToken([t1155.address, 2, 21, tokenId])
			).to.be.revertedWith("Insufficient balance to tokenize");
		});

		it("Should tokenize ERC20 asset when untokenized balance is sufficient", async function() {
			await wallet.mintAssetTransferRightsToken([t20.address, 0, tokenAmount - 20, 0]);

			await expect(
				wallet.mintAssetTransferRightsToken([t20.address, 0, 20, 0])
			).to.not.be.reverted;
		});

		it("Should tokenize ERC1155 asset when untokenized balance is sufficient", async function() {
			await wallet.mintAssetTransferRightsToken([t1155.address, 2, tokenAmount - 20, tokenId]);

			await expect(
				wallet.mintAssetTransferRightsToken([t1155.address, 2, 20, tokenId])
			).to.not.be.reverted;
		});

		it("Should fail if asset collection has operator set", async function() {
			await wallet.execute(
				t721.address,
				Iface.ERC721.encodeFunctionData("setApprovalForAll", [owner.address, true])
			);

			await expect(
				wallet.mintAssetTransferRightsToken([t721.address, 1, 1, tokenId])
			).to.be.revertedWith("Some asset from collection has an approval");
		});

		it("Should increate ATR token id", async function() {
			const lastTokenId = await atr.lastTokenId();

			await wallet.mintAssetTransferRightsToken([t721.address, 1, 1, tokenId]);

			expect(await atr.lastTokenId()).to.equal(lastTokenId + 1);
		});

		it("Should store tokenized asset data", async function() {
			await wallet.mintAssetTransferRightsToken([t721.address, 1, 1, tokenId]);

			const asset = await atr.getAsset(1);
			expect(asset.assetAddress).to.equal(t721.address);
			expect(asset.category).to.equal(1);
			expect(asset.amount).to.equal(1);
			expect(asset.id).to.equal(tokenId);
		});

		it("Should store that sender has tokenized asset in wallet", async function() {
			await wallet.mintAssetTransferRightsToken([t721.address, 1, 1, tokenId]);

			const ownedAssets = await wallet.callStatic.execute(
				atr.address,
				Iface.ATR.encodeFunctionData("ownedAssetATRIds", [])
			);
			const decodedOwnedAssets = Iface.ATR.decodeFunctionResult("ownedAssetATRIds", ownedAssets)[0];
			expect(decodedOwnedAssets[0].toNumber()).to.equal(1);
		});

		it("Should mint ATR token", async function() {
			await expect(
				wallet.mintAssetTransferRightsToken([t721.address, 1, 1, tokenId])
			).to.not.be.reverted;

			expect(await atr.ownerOf(1)).to.equal(wallet.address);
		});

	});


	describe("Burn", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await t721.mint(wallet.address, tokenId);

			// ATR token with id 1
			await wallet.mintAssetTransferRightsToken([t721.address, 1, 1, tokenId]);
		});


		it("Should fail when sender is not ATR token owner", async function() {
			// Transfer ATR token to `other`
			await wallet.execute(
				atr.address,
				Iface.ERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 1])
			);

			await expect(
				wallet.burnAssetTransferRightsToken(1)
			).to.be.revertedWith("Caller is not ATR token owner");
		});

		it("Should fail when ATR token is not minted", async function() {
			await expect(
				wallet.burnAssetTransferRightsToken(2)
			).to.be.revertedWith("Asset transfer rights are not tokenized");
		});

		it("Should fail when sender is not tokenized asset owner", async function() {
			// Transfer ATR token to `otherWallet`
			await wallet.execute(
				atr.address,
				Iface.ERC721.encodeFunctionData("transferFrom", [wallet.address, walletOther.address, 1])
			);

			await expect(
				walletOther.connect(other).burnAssetTransferRightsToken(1)
			).to.be.revertedWith("Insufficient balance of a tokenize asset");
		});

		it("Should clear stored tokenized asset data", async function() {
			await wallet.burnAssetTransferRightsToken(1);

			const asset = await atr.getAsset(1);
			expect(asset.assetAddress).to.equal(ethers.constants.AddressZero);
			expect(asset.category).to.equal(0);
			expect(asset.amount).to.equal(0);
			expect(asset.id).to.equal(0);
		});

		it("Should remove stored tokenized asset info from senders wallet", async function() {
			await wallet.burnAssetTransferRightsToken(1);

			const ownedAssets = await wallet.callStatic.execute(
				atr.address,
				Iface.ATR.encodeFunctionData("ownedAssetATRIds", [])
			);
			const decodedOwnedAssets = Iface.ATR.decodeFunctionResult("ownedAssetATRIds", ownedAssets)[0];
			expect(decodedOwnedAssets).to.be.empty;
		});

		it("Should burn ATR token", async function() {
			await wallet.burnAssetTransferRightsToken(1);

			await expect(
				atr.ownerOf(1)
			).to.be.reverted;
		});

	});


	describe("Transfer asset from", async function() {

		const tokenId = 123;
		const tokenAmount = 12332;

		beforeEach(async function() {
			await t20.mint(walletOther.address, tokenAmount);
			await t721.mint(walletOther.address, tokenId);
			await t1155.mint(walletOther.address, tokenId, tokenAmount);

			// ATR tokens with ids 1, 2, 3
			await walletOther.connect(other).mintAssetTransferRightsToken([t20.address, 0, tokenAmount, 0]);
			await walletOther.connect(other).mintAssetTransferRightsToken([t721.address, 1, 1, tokenId]);
			await walletOther.connect(other).mintAssetTransferRightsToken([t1155.address, 2, tokenAmount, tokenId]);

			const calldata = (id) => {
				return Iface.ERC721.encodeFunctionData("transferFrom", [walletOther.address, wallet.address, id]);
			}

			// Transfer ATR tokens with ids 1, 2, 3 to `wallet`
			await walletOther.connect(other).execute(atr.address, calldata(1));
			await walletOther.connect(other).execute(atr.address, calldata(2));
			await walletOther.connect(other).execute(atr.address, calldata(3));
		});


		it("Should fail when token rights are not tokenized", async function() {
			await expect(
				wallet.transferAssetFrom(walletOther.address, 4, false)
			).to.be.revertedWith("Transfer rights are not tokenized");
		});

		it("Should fail when sender is not ATR token owner", async function() {
			await expect(
				walletEmpty.connect(other).transferAssetFrom(walletOther.address, 2, false)
			).to.be.revertedWith("Caller is not ATR token owner");
		});

		it("Should fail when asset is not in wallet", async function() {
			await expect(
				wallet.transferAssetFrom(walletEmpty.address, 2, false)
			).to.be.revertedWith("Asset is not in a target wallet");
		});

		it("Should fail when transferring asset to same address", async function() {
			await expect(
				walletOther.connect(other).transferAssetFrom(walletOther.address, 2, false)
			).to.be.revertedWith("Attempting to transfer asset to the same address");
		});

		it("Should remove stored tokenized asset info from senders wallet", async function() {
			// Transfer asset from `walletOther` via ATR token
			await wallet.transferAssetFrom(walletOther.address, 2, false);

			// Asset is no longer in `walletOther`
			const ownedAssets = await walletOther.connect(other).callStatic.execute(
				atr.address,
				Iface.ATR.encodeFunctionData("ownedAssetATRIds", [])
			);
			const decodedOwnedAssets = Iface.ATR.decodeFunctionResult("ownedAssetATRIds", ownedAssets)[0];
			expect(decodedOwnedAssets.map(bn => bn.toNumber())).to.not.contain(2);
		});

		it("Should transfer ERC20 asset when sender has tokenized transfer rights", async function() {
			// Transfer asset from `walletOther` via ATR token
			await wallet.transferAssetFrom(walletOther.address, 1, false);

			// Assets owner is `wallet` now
			expect(await t20.balanceOf(wallet.address)).to.equal(tokenAmount);
		});

		it("Should transfer ERC721 asset when sender has tokenized transfer rights", async function() {
			// Transfer asset from `walletOther` via ATR token
			await wallet.transferAssetFrom(walletOther.address, 2, false);

			// Assets owner is `wallet` now
			expect(await t721.ownerOf(tokenId)).to.equal(wallet.address);
		});

		it("Should transfer ERC1155 asset when sender has tokenized transfer rights", async function() {
			// Transfer asset from `walletOther` via ATR token
			await wallet.transferAssetFrom(walletOther.address, 3, false);

			// Assets owner is `wallet` now
			expect(await t1155.balanceOf(wallet.address, tokenId)).to.equal(tokenAmount);
		});

		describe("Without `burnToken` flag", function() {

			it("Should store that sender has tokenized asset in wallet", async function() {
				// Transfer asset from `walletOther` via ATR token
				await wallet.transferAssetFrom(walletOther.address, 2, false);

				// Asset is in `wallet`
				const ownedAssets = await wallet.callStatic.execute(
					atr.address,
					Iface.ATR.encodeFunctionData("ownedAssetATRIds", [])
				);
				const decodedOwnedAssets = Iface.ATR.decodeFunctionResult("ownedAssetATRIds", ownedAssets)[0];
				expect(decodedOwnedAssets.map(bn => bn.toNumber())).to.contain(2);
			});

			it("Should fail if recipient wallet has approval for asset", async function() {
				// Set operator for asset collection
				await wallet.execute(
					t721.address,
					Iface.ERC721.encodeFunctionData("setApprovalForAll", [owner.address, true])
				);

				// Try to transfer asset from `walletOther` via ATR token
				await expect(
					wallet.transferAssetFrom(walletOther.address, 2, false)
				).to.be.revertedWith("Receiver has approvals set for an asset");
			});

			it("Should fail when transferring to other than PWN Wallet", async function() {
				// Transfer ATR token to `other`
				await wallet.execute(
					atr.address,
					Iface.ERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 2])
				);

				// Try to transfer asset from `walletOther` via ATR token
				await expect(
					atr.connect(other).transferAssetFrom(walletOther.address, 2, false)
				).to.be.revertedWith("Attempting to transfer asset to non PWN Wallet address");
			});

		});

		describe("With `burnToken` flag", function() {

			it("Should clear stored tokenized asset data", async function() {
				// Transfer asset from `walletOther` via ATR token
				await wallet.transferAssetFrom(walletOther.address, 2, true);

				const asset = await atr.getAsset(2);
				expect(asset.assetAddress).to.equal(ethers.constants.AddressZero);
				expect(asset.category).to.equal(0);
				expect(asset.amount).to.equal(0);
				expect(asset.id).to.equal(0);
			});

			it("Should burn ATR token", async function() {
				// Transfer asset from `walletOther` via ATR token
				await wallet.transferAssetFrom(walletOther.address, 2, true);

				await expect(atr.ownerOf(2)).to.be.reverted;
			});

			it("Should transfer asset to any address (not just PWN wallet)", async function() {
				// Transfer ATR token to `other`
				await wallet.execute(
					atr.address,
					Iface.ERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, 2])
				);

				// Transfer asset from `walletOther` via ATR token
				await atr.connect(other).transferAssetFrom(walletOther.address, 2, true);

				expect(await t721.ownerOf(tokenId)).to.equal(other.address);
			});

		});

	});


	describe("Get asset", function() {

		async function areEqual(assetId, values) {
			const asset = await atr.getAsset(assetId);

			return asset.assetAddress == values[0] &&
				asset.category == values[1] &&
				asset.amount.toNumber() == values[2] &&
				asset.id.toNumber() == values[3];
		};


		it("Should return stored asset", async function() {
			const tokenId = 123;
			const tokenAmount = 12332;

			await t20.mint(wallet.address, tokenAmount);
			await t721.mint(wallet.address, tokenId);
			await t1155.mint(wallet.address, tokenId, tokenAmount);

			// ATR tokens with ids 1, 2, 3
			await wallet.mintAssetTransferRightsToken([t20.address, 0, tokenAmount, 0]);
			await wallet.mintAssetTransferRightsToken([t721.address, 1, 1, tokenId]);
			await wallet.mintAssetTransferRightsToken([t1155.address, 2, tokenAmount, tokenId]);

			expect(await areEqual(1, [t20.address, 0, tokenAmount, 0])).to.equal(true);
			expect(await areEqual(2, [t721.address, 1, 1, tokenId])).to.equal(true);
			expect(await areEqual(3, [t1155.address, 2, tokenAmount, tokenId])).to.equal(true);
		});

	});


	describe("Owned asset ATR ids", function() {

		it("Should return list of tokenized assets in senders wallet represented by their ATR token id", async function() {
			const tokenId = 123;
			const tokenAmount = 12332;

			await t20.mint(wallet.address, tokenAmount);
			await t721.mint(wallet.address, tokenId);
			await t1155.mint(wallet.address, tokenId, tokenAmount);

			// ATR tokens with ids 1, 2, 3
			await wallet.mintAssetTransferRightsToken([t20.address, 0, tokenAmount, 0]);
			await wallet.mintAssetTransferRightsToken([t721.address, 1, 1, tokenId]);
			await wallet.mintAssetTransferRightsToken([t1155.address, 2, tokenAmount, tokenId]);

			const ownedAssets = await wallet.callStatic.execute(
				atr.address,
				Iface.ATR.encodeFunctionData("ownedAssetATRIds", [])
			);

			const decodedOwnedAssets = Iface.ATR.decodeFunctionResult("ownedAssetATRIds", ownedAssets)[0];
			const ids = decodedOwnedAssets.map(bn => bn.toNumber());

			expect(ids).to.include.members([1, 2, 3]);
		});

	});


	describe("Owned from collection", function() {

		it("Should return number of tokenized assets from given contract address", async function() {
			await t721.mint(wallet.address, 2);
			await t721.mint(wallet.address, 3);

			await wallet.mintAssetTransferRightsToken([t721.address, 1, 1, 2]);
			await wallet.mintAssetTransferRightsToken([t721.address, 1, 1, 3]);

			let ownedFromERC20Collection = await wallet.callStatic.execute(
				atr.address,
				Iface.ATR.encodeFunctionData("ownedFromCollection", [t20.address])
			);

			ownedFromERC20Collection = Iface.ATR.decodeFunctionResult("ownedFromCollection", ownedFromERC20Collection)[0];
			expect(ownedFromERC20Collection.toNumber()).to.equal(0);


			let ownedFromERC721Collection = await wallet.callStatic.execute(
				atr.address,
				Iface.ATR.encodeFunctionData("ownedFromCollection", [t721.address])
			);

			ownedFromERC721Collection = Iface.ATR.decodeFunctionResult("ownedFromCollection", ownedFromERC721Collection)[0];
			expect(ownedFromERC721Collection.toNumber()).to.equal(2);

			await wallet.burnAssetTransferRightsToken(1);
			await wallet.burnAssetTransferRightsToken(2);

			ownedFromERC721Collection = await wallet.callStatic.execute(
				atr.address,
				Iface.ATR.encodeFunctionData("ownedFromCollection", [t721.address])
			);

			ownedFromERC721Collection = Iface.ATR.decodeFunctionResult("ownedFromCollection", ownedFromERC721Collection)[0];
			expect(ownedFromERC721Collection.toNumber()).to.equal(0);
		});

	});


	describe("Tokenized balance of", function() {

		it("Should return balance of tokenized fungible asset in callers wallet", async function() {
			let res, balance;

			await t20.mint(wallet.address, 100);

			res = await wallet.callStatic.execute(
				atr.address,
				Iface.ATR.encodeFunctionData("tokenizedBalanceOf", [[t20.address, 0, 1, 0]])
			);
			balance = Iface.ATR.decodeFunctionResult("tokenizedBalanceOf", res)[0];

			expect(balance).to.equal(0);


			await wallet.mintAssetTransferRightsToken([t20.address, 0, 10, 0]);

			res = await wallet.callStatic.execute(
				atr.address,
				Iface.ATR.encodeFunctionData("tokenizedBalanceOf", [[t20.address, 0, 1, 0]])
			);
			balance = Iface.ATR.decodeFunctionResult("tokenizedBalanceOf", res)[0];

			expect(balance).to.equal(10);


			await wallet.mintAssetTransferRightsToken([t20.address, 0, 70, 0]);

			res = await wallet.callStatic.execute(
				atr.address,
				Iface.ATR.encodeFunctionData("tokenizedBalanceOf", [[t20.address, 0, 1, 0]])
			);
			balance = Iface.ATR.decodeFunctionResult("tokenizedBalanceOf", res)[0];

			expect(balance).to.equal(80);


			await wallet.burnAssetTransferRightsToken(1);

			res = await wallet.callStatic.execute(
				atr.address,
				Iface.ATR.encodeFunctionData("tokenizedBalanceOf", [[t20.address, 0, 1, 0]])
			);
			balance = Iface.ATR.decodeFunctionResult("tokenizedBalanceOf", res)[0];

			expect(balance).to.equal(70);


			await wallet.burnAssetTransferRightsToken(2);

			res = await wallet.callStatic.execute(
				atr.address,
				Iface.ATR.encodeFunctionData("tokenizedBalanceOf", [[t20.address, 0, 1, 0]])
			);
			balance = Iface.ATR.decodeFunctionResult("tokenizedBalanceOf", res)[0];

			expect(balance).to.equal(0);
		});

		it("Should return balance of tokenized non-fungible asset in callers wallet", async function() {
			let res, balance;

			await t721.mint(wallet.address, 1);
			await t721.mint(wallet.address, 2);

			res = await wallet.callStatic.execute(
				atr.address,
				Iface.ATR.encodeFunctionData("tokenizedBalanceOf", [[t721.address, 1, 1, 1]])
			);
			balance = Iface.ATR.decodeFunctionResult("tokenizedBalanceOf", res)[0];

			expect(balance).to.equal(0);


			await wallet.mintAssetTransferRightsToken([t721.address, 1, 1, 1]);
			await wallet.mintAssetTransferRightsToken([t721.address, 1, 1, 2]);

			res = await wallet.callStatic.execute(
				atr.address,
				Iface.ATR.encodeFunctionData("tokenizedBalanceOf", [[t721.address, 1, 1, 1]])
			);
			balance = Iface.ATR.decodeFunctionResult("tokenizedBalanceOf", res)[0];

			expect(balance).to.equal(1);


			await wallet.burnAssetTransferRightsToken(1);

			res = await wallet.callStatic.execute(
				atr.address,
				Iface.ATR.encodeFunctionData("tokenizedBalanceOf", [[t721.address, 1, 1, 1]])
			);
			balance = Iface.ATR.decodeFunctionResult("tokenizedBalanceOf", res)[0];

			expect(balance).to.equal(0);
		});

	});

});
