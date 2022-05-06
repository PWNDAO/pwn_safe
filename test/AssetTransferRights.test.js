const chai = require("chai");
const { ethers } = require("hardhat");
const { smock } = require("@defi-wonderland/smock");
const utils = ethers.utils;
const Iface = require("./sharedIfaces.js");
const { deploy1820Registry } = require("../scripts/testDeploy1820Registry.js");
const { CATEGORY, getPermissionHashBytes, signPermission } = require("./test-helpers.js");
const { ERC20, ERC721, ERC1155 } = CATEGORY;

const expect = chai.expect;
chai.use(smock.matchers);


describe("AssetTransferRights", function() {

	let ATR, atr;
	let wallet, walletOther;
	let factory;
	let T20, T721, T1155;
	let t20, t721, t1155;
	let owner, other, addr1;

	async function deployNewWallet(signer) {
		const walletTx = await factory.connect(signer).newWallet();
		const walletRes = await walletTx.wait();
		return await ethers.getContractAt("PWNWallet", walletRes.events[1].args.walletAddress);
	}

	before(async function() {
		ATR = await ethers.getContractFactory("AssetTransferRights");
		T20 = await ethers.getContractFactory("T20");
		T721 = await ethers.getContractFactory("T721");
		T1155 = await ethers.getContractFactory("T1155");

		[owner, other, addr1] = await ethers.getSigners();

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

		wallet = await deployNewWallet(owner);
		walletOther = await deployNewWallet(other);
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
				atr.connect(other).mintAssetTransferRightsToken([t721.address, ERC721, 1, 333])
			).to.be.revertedWith("Caller is not a PWN Wallet");
		});

		it("Should fail when sender is not asset owner", async function() {
			await t721.mint(owner.address, 3232);

			await expect(
				wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, 3232])
			).to.be.revertedWith("Insufficient balance to tokenize");
		});

		it("Should fail when trying to tokenize zero address asset", async function() {
			await expect(
				wallet.mintAssetTransferRightsToken([ethers.constants.AddressZero, ERC721, 1, 3232])
			).to.be.revertedWith("Attempting to tokenize zero address asset");
		});

		it("Should fail when trying to tokenize ATR token", async function() {
			await expect(
				wallet.mintAssetTransferRightsToken([atr.address, ERC721, 1, 3232])
			).to.be.revertedWith("Attempting to tokenize ATR token");
		});

		it("Should fail when asset is invalid", async function() {
			await expect(
				wallet.mintAssetTransferRightsToken([t721.address, ERC721, 0, tokenId])
			).to.be.revertedWith("MultiToken.Asset is not valid");
		});

		it("Should fail when ERC721 asset is approved", async function() {
			await wallet.execute(
				t721.address,
				Iface.ERC721.encodeFunctionData("approve", [owner.address, tokenId])
			);

			await expect(
				wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId])
			).to.be.revertedWith("Tokenized asset has an approved address");
		});

		describe("Asset category", function() {

			describe("Asset implementing ERC165", function() {

				it("Should fail when passing ERC20 asset with ERC721 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t20.address, ERC721, 1, 132])
					).to.be.revertedWith("Invalid provided category");
				});

				it("Should fail when passing ERC20 asset with ERC1155 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t20.address, ERC1155, tokenAmount, 0])
					).to.be.revertedWith("Invalid provided category");
				});

				it("Should fail when passing ERC721 asset with ERC20 category", async function() {
					await t721.mint(wallet.address, 0);

					await expect(
						wallet.mintAssetTransferRightsToken([t721.address, ERC20, 1, 0])
					).to.be.revertedWith("Invalid provided category");
				});

				it("Should fail when passing ERC721 asset with ERC1155 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t721.address, ERC1155, 1, tokenId])
					).to.be.revertedWith("Invalid provided category");
				});

				it("Should fail when passing ERC1155 asset with ERC20 category", async function() {
					await t1155.mint(wallet.address, 0, tokenAmount);

					await expect(
						wallet.mintAssetTransferRightsToken([t1155.address, ERC20, tokenAmount, 0])
					).to.be.revertedWith("Invalid provided category");
				});

				it("Should fail when passing ERC1155 asset with ERC721 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t1155.address, ERC721, 1, tokenId])
					).to.be.revertedWith("Invalid provided category");
				});

				it("Should mint ATR token for ERC20 asset with ERC20 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t20.address, ERC20, tokenAmount, 0])
					).to.not.be.reverted;
				});

				it("Should mint ATR token for ERC721 asset with ERC721 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId])
					).to.not.be.reverted;
				});

				it("Should mint ATR token for ERC1155 asset with ERC1155 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t1155.address, ERC1155, tokenAmount, tokenId])
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
						wallet.mintAssetTransferRightsToken([t20.address, ERC721, 1, 132])
					).to.be.reverted;
				});

				it("Should fail when passing ERC20 asset with ERC1155 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t20.address, ERC1155, tokenAmount, 0])
					).to.be.reverted;
				});

				it("Should fail when passing ERC721 asset with ERC20 category", async function() {
					await t721.mint(wallet.address, 0);

					await expect(
						wallet.mintAssetTransferRightsToken([t721.address, ERC20, 1, 0])
					).to.be.revertedWith("Invalid provided category");
				});

				it("Should fail when passing ERC721 asset with ERC1155 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t721.address, ERC1155, 1, tokenId])
					).to.be.reverted;
				});

				it("Should fail when passing ERC1155 asset with ERC20 category", async function() {
					await t1155.mint(wallet.address, 0, tokenAmount);

					await expect(
						wallet.mintAssetTransferRightsToken([t1155.address, ERC20, tokenAmount, 0])
					).to.be.reverted;
				});

				it("Should fail when passing ERC1155 asset with ERC721 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t1155.address, ERC721, 1, tokenId])
					).to.be.reverted;
				});

				it("Should mint ATR token for ERC20 asset with ERC20 category", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t20.address, ERC20, tokenAmount, 0])
					).to.not.be.reverted;
				});

				it("Should fail when passing ERC721 which doesn't implement ERC165", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId])
					).to.be.revertedWith("Invalid provided category");
				});

				it("Should fail when passing ERC1155 which doesn't implement ERC165", async function() {
					await expect(
						wallet.mintAssetTransferRightsToken([t1155.address, ERC1155, tokenAmount, tokenId])
					).to.be.revertedWith("Invalid provided category");
				});

			});

		});

		it("Should fail when ERC20 asset doesn't have enough untokenized balance to tokenize without any tokenized asset", async function() {
			await expect(
				wallet.mintAssetTransferRightsToken([t20.address, ERC20, tokenAmount + 1, 0])
			).to.be.revertedWith("Insufficient balance to tokenize");
		});

		it("Should fail when ERC1155 asset doesn't have enough untokenized balance to tokenize without any tokenized asset", async function() {
			await expect(
				wallet.mintAssetTransferRightsToken([t1155.address, ERC1155, tokenAmount + 1, tokenId])
			).to.be.revertedWith("Insufficient balance to tokenize");
		});

		it("Should fail when ERC20 asset doesn't have enough untokenized balance to tokenize with some tokenized asset", async function() {
			await wallet.mintAssetTransferRightsToken([t20.address, ERC20, tokenAmount - 20, 0]);

			await expect(
				wallet.mintAssetTransferRightsToken([t20.address, ERC20, 21, 0])
			).to.be.revertedWith("Insufficient balance to tokenize");
		});

		it("Should fail when ERC721 asset is already tokenised", async function() {
			await wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId]);

			await expect(
				wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId])
			).to.be.revertedWith("Insufficient balance to tokenize");
		});

		it("Should fail when ERC1155 asset doesn't have enough untokenized balance to tokenize with some tokenized asset", async function() {
			await wallet.mintAssetTransferRightsToken([t1155.address, ERC1155, tokenAmount - 20, tokenId]);

			await expect(
				wallet.mintAssetTransferRightsToken([t1155.address, ERC1155, 21, tokenId])
			).to.be.revertedWith("Insufficient balance to tokenize");
		});

		it("Should tokenize ERC20 asset when untokenized balance is sufficient", async function() {
			await wallet.mintAssetTransferRightsToken([t20.address, ERC20, tokenAmount - 20, 0]);

			await expect(
				wallet.mintAssetTransferRightsToken([t20.address, ERC20, 20, 0])
			).to.not.be.reverted;
		});

		it("Should tokenize ERC1155 asset when untokenized balance is sufficient", async function() {
			await wallet.mintAssetTransferRightsToken([t1155.address, ERC1155, tokenAmount - 20, tokenId]);

			await expect(
				wallet.mintAssetTransferRightsToken([t1155.address, ERC1155, 20, tokenId])
			).to.not.be.reverted;
		});

		it("Should fail if asset collection has operator set", async function() {
			await wallet.execute(
				t721.address,
				Iface.ERC721.encodeFunctionData("setApprovalForAll", [owner.address, true])
			);

			await expect(
				wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId])
			).to.be.revertedWith("Some asset from collection has an approval");
		});

		it("Should increate ATR token id", async function() {
			const lastTokenId = await atr.lastTokenId();

			await wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId]);

			expect(await atr.lastTokenId()).to.equal(lastTokenId + 1);
		});

		it("Should store tokenized asset data", async function() {
			await wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId]);

			const asset = await atr.getAsset(1);
			expect(asset.assetAddress).to.equal(t721.address);
			expect(asset.category).to.equal(ERC721);
			expect(asset.amount).to.equal(1);
			expect(asset.id).to.equal(tokenId);
		});

		it("Should store that sender has tokenized asset in wallet", async function() {
			await wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId]);

			const ids = await atr.ownedAssetATRIds(wallet.address);
			expect(ids[0].toNumber()).to.equal(1);
		});

		it("Should mint ATR token", async function() {
			await expect(
				wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId])
			).to.not.be.reverted;

			expect(await atr.ownerOf(1)).to.equal(wallet.address);
		});

	});


	describe("Burn", function() {

		const tokenId = 123;

		beforeEach(async function() {
			await t721.mint(wallet.address, tokenId);

			// ATR token with id 1
			await wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId]);
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

			const ids = await atr.ownedAssetATRIds(wallet.address);
			expect(ids.map(bn => bn.toNumber())).to.be.empty;
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

		async function mint20() {
			await t20.mint(walletOther.address, tokenAmount);
			return await mintAtr([t20.address, ERC20, tokenAmount, 0]);
		}

		async function mint721() {
			await t721.mint(walletOther.address, tokenId);
			return await mintAtr([t721.address, ERC721, 1, tokenId]);
		}

		async function mint1155() {
			await t1155.mint(walletOther.address, tokenId, tokenAmount);
			return await mintAtr([t1155.address, ERC1155, tokenAmount, tokenId]);
		}

		async function mintAtr(asset) {
			const tx = await walletOther.connect(other).mintAssetTransferRightsToken(asset);
			const res = await tx.wait();
			const log = Iface.ERC721.decodeEventLog("Transfer", res.events[0].data, res.events[0].topics);
			await walletOther.connect(other).execute(
				atr.address,
				Iface.ERC721.encodeFunctionData("transferFrom", [walletOther.address, wallet.address, log.tokenId])
			);

			return log.tokenId;
		}


		it("Should fail when token rights are not tokenized", async function() {
			await expect(
				wallet.transferAssetFrom(walletOther.address, 4, false)
			).to.be.revertedWith("Transfer rights are not tokenized");
		});

		it("Should fail when sender is not ATR token owner", async function() {
			const walletEmpty = await deployNewWallet(other);
			const atrTokenId = await mint721();

			await expect(
				walletEmpty.connect(other).transferAssetFrom(walletOther.address, atrTokenId, false)
			).to.be.revertedWith("Caller is not ATR token owner");
		});

		it("Should fail when asset is not in wallet", async function() {
			const walletEmpty = await deployNewWallet(other);
			const atrTokenId = await mint721();

			await expect(
				wallet.transferAssetFrom(walletEmpty.address, atrTokenId, false)
			).to.be.revertedWith("Asset is not in a target wallet");
		});

		it("Should fail when transferring asset to same address", async function() {
			const atrTokenId = await mint721();

			await expect(
				walletOther.connect(other).transferAssetFrom(walletOther.address, atrTokenId, false)
			).to.be.revertedWith("Attempting to transfer asset to the same address");
		});

		it("Should remove stored tokenized asset info from senders wallet", async function() {
			const atrTokenId = await mint721();

			// Transfer asset from `walletOther` via ATR token
			await wallet.transferAssetFrom(walletOther.address, atrTokenId, false);

			// Asset is no longer in `walletOther`
			const ids = await atr.ownedAssetATRIds(walletOther.address);
			expect(ids.map(bn => bn.toNumber())).to.not.contain(atrTokenId.toNumber());
		});

		it("Should transfer ERC20 asset when sender has tokenized transfer rights", async function() {
			const atrTokenId = await mint20();

			// Transfer asset from `walletOther` via ATR token
			await wallet.transferAssetFrom(walletOther.address, atrTokenId, false);

			// Assets owner is `wallet` now
			expect(await t20.balanceOf(wallet.address)).to.equal(tokenAmount);
		});

		it("Should transfer ERC721 asset when sender has tokenized transfer rights", async function() {
			const atrTokenId = await mint721();

			// Transfer asset from `walletOther` via ATR token
			await wallet.transferAssetFrom(walletOther.address, atrTokenId, false);

			// Assets owner is `wallet` now
			expect(await t721.ownerOf(tokenId)).to.equal(wallet.address);
		});

		it("Should transfer ERC1155 asset when sender has tokenized transfer rights", async function() {
			const atrTokenId = await mint1155();

			// Transfer asset from `walletOther` via ATR token
			await wallet.transferAssetFrom(walletOther.address, atrTokenId, false);

			// Assets owner is `wallet` now
			expect(await t1155.balanceOf(wallet.address, tokenId)).to.equal(tokenAmount);
		});

		describe("Without `burnToken` flag", function() {

			it("Should store that sender has tokenized asset in wallet", async function() {
				const atrTokenId = await mint721();

				// Transfer asset from `walletOther` via ATR token
				await wallet.transferAssetFrom(walletOther.address, atrTokenId, false);

				// Asset is in `wallet`
				const ids = await atr.ownedAssetATRIds(wallet.address);
				expect(ids.map(bn => bn.toNumber())).to.contain(atrTokenId.toNumber());
			});

			it("Should fail if recipient wallet has approval for asset", async function() {
				const atrTokenId = await mint721();

				// Set operator for asset collection
				await wallet.execute(
					t721.address,
					Iface.ERC721.encodeFunctionData("setApprovalForAll", [owner.address, true])
				);

				// Try to transfer asset from `walletOther` via ATR token
				await expect(
					wallet.transferAssetFrom(walletOther.address, atrTokenId, false)
				).to.be.revertedWith("Receiver has approvals set for an asset");
			});

			it("Should fail when transferring to other than PWN Wallet", async function() {
				const atrTokenId = await mint721();

				// Transfer ATR token to `other`
				await wallet.execute(
					atr.address,
					Iface.ERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, atrTokenId])
				);

				// Try to transfer asset from `walletOther` via ATR token
				await expect(
					atr.connect(other).transferAssetFrom(walletOther.address, atrTokenId, false)
				).to.be.revertedWith("Attempting to transfer asset to non PWN Wallet address");
			});

		});

		describe("With `burnToken` flag", function() {

			it("Should clear stored tokenized asset data", async function() {
				const atrTokenId = await mint721();

				// Transfer asset from `walletOther` via ATR token
				await wallet.transferAssetFrom(walletOther.address, atrTokenId, true);

				const asset = await atr.getAsset(atrTokenId);
				expect(asset.assetAddress).to.equal(ethers.constants.AddressZero);
				expect(asset.category).to.equal(0);
				expect(asset.amount).to.equal(0);
				expect(asset.id).to.equal(0);
			});

			it("Should burn ATR token", async function() {
				const atrTokenId = await mint721();

				// Transfer asset from `walletOther` via ATR token
				await wallet.transferAssetFrom(walletOther.address, atrTokenId, true);

				await expect(atr.ownerOf(2)).to.be.reverted;
			});

			it("Should transfer asset to any address (not just PWN wallet)", async function() {
				const atrTokenId = await mint721();

				// Transfer ATR token to `other`
				await wallet.execute(
					atr.address,
					Iface.ERC721.encodeFunctionData("transferFrom", [wallet.address, other.address, atrTokenId])
				);

				// Transfer asset from `walletOther` via ATR token
				await atr.connect(other).transferAssetFrom(walletOther.address, atrTokenId, true);

				expect(await t721.ownerOf(tokenId)).to.equal(other.address);
			});

		});

	});


	describe("Transfer asset with permission from", function() {

		// Transferring asset from `walletOther` to `wallet` via ATR token owned by `addr1`, which is not owner of any of these wallets

		const tokenId = 123;
		const tokenAmount = 12332;
		const nonce = ethers.utils.solidityKeccak256([ "string" ], [ "nonce" ]);
		let permission, permissionSignature;

		async function mint20() {
			await t20.mint(walletOther.address, tokenAmount);
			return await mintAtr([t20.address, ERC20, tokenAmount, 0]);
		}

		async function mint721() {
			await t721.mint(walletOther.address, tokenId);
			return await mintAtr([t721.address, ERC721, 1, tokenId]);
		}

		async function mint1155() {
			await t1155.mint(walletOther.address, tokenId, tokenAmount);
			return await mintAtr([t1155.address, ERC1155, tokenAmount, tokenId]);
		}

		async function mintAtr(asset) {
			const tx = await walletOther.connect(other).mintAssetTransferRightsToken(asset);
			const res = await tx.wait();
			const log = Iface.ERC721.decodeEventLog("Transfer", res.events[0].data, res.events[0].topics);
			await walletOther.connect(other).execute(
				atr.address,
				Iface.ERC721.encodeFunctionData("transferFrom", [walletOther.address, addr1.address, log.tokenId])
			);

			return log.tokenId;
		}

		beforeEach(async function() {
			permission = [owner.address, wallet.address, nonce];
			permissionSignature = await signPermission(permission, atr.address, owner);
		});


		it("Should fail when permission is not signer by stated EOA wallet owner", async function() {
			const atrTokenId = await mint721();

			permissionSignature = await signPermission(permission, atr.address, other);

			await expect(
				atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, false, permission, permissionSignature)
			).to.be.revertedWith("Permission signer is not stated as wallet owner");
		});

		it("Should fail when permission is not signer by stated contract wallet owner", async function() {
			const atrTokenId = await mint721();

			const ContractWallet = await ethers.getContractFactory("ContractWallet");
			const contractWallet = await ContractWallet.deploy();

			await wallet.connect(owner).transferOwnership(contractWallet.address);

			permission = [contractWallet.address, wallet.address, nonce];
			// Sign by `other` signer, not `owner`
			permissionSignature = await signPermission(permission, atr.address, other);

			await expect(
				atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, false, permission, permissionSignature)
			).to.be.revertedWith("Signature on behalf of contract is invalid");
		});

		it("Should fail when permission is revoked", async function() {
			const atrTokenId = await mint721();

			const permisisonHash = getPermissionHashBytes(permission, atr.address);
			await atr.connect(owner).revokeRecipientPermisison(permisisonHash, permissionSignature);

			await expect(
				atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, false, permission, permissionSignature)
			).to.be.revertedWith("Recipient permission is revoked");
		});

		it("Should fail when stated wallet owner is not real wallet owner", async function() {
			const walletEmpty = await deployNewWallet(other);
			const atrTokenId = await mint721();

			permission = [owner.address, walletEmpty.address, nonce];
			permissionSignature = await signPermission(permission, atr.address, owner);

			await expect(
				atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, false, permission, permissionSignature)
			).to.be.revertedWith("Permission signer is not wallet owner");
		});

		it("Should fail when token rights are not tokenized", async function() {
			await expect(
				atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, 4, false, permission, permissionSignature)
			).to.be.revertedWith("Transfer rights are not tokenized");
		});

		it("Should fail when sender is not ATR token owner", async function() {
			const atrTokenId = await mint721();

			await expect(
				atr.connect(other).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, false, permission, permissionSignature)
			).to.be.revertedWith("Caller is not ATR token owner");
		});

		it("Should fail when asset is not in wallet", async function() {
			const walletEmpty = await deployNewWallet(other);
			const atrTokenId = await mint721();

			await expect(
				atr.connect(addr1).transferAssetWithPermissionFrom(walletEmpty.address, atrTokenId, false, permission, permissionSignature)
			).to.be.revertedWith("Asset is not in a target wallet");
		});

		it("Should fail when transferring asset to same address", async function() {
			const atrTokenId = await mint721();

			permission = [other.address, walletOther.address, nonce];
			permissionSignature = await signPermission(permission, atr.address, other);

			await expect(
				atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, false, permission, permissionSignature)
			).to.be.revertedWith("Attempting to transfer asset to the same address");
		});

		it("Should remove stored tokenized asset info from senders wallet", async function() {
			const atrTokenId = await mint721();

			// Transfer asset from `walletOther` via ATR token
			await atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, false, permission, permissionSignature);

			// Asset is no longer in `walletOther`
			const ids = await atr.ownedAssetATRIds(walletOther.address);
			expect(ids.map(bn => bn.toNumber())).to.not.contain(atrTokenId.toNumber());
		});

		describe("from EOA", function() {

			it("Should transfer ERC20 asset when sender has tokenized transfer rights", async function() {
				const atrTokenId = await mint20();

				// Transfer asset from `walletOther` via ATR token
				await atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, false, permission, permissionSignature);

				// Assets owner is `wallet` now
				expect(await t20.balanceOf(wallet.address)).to.equal(tokenAmount);
			});

			it("Should transfer ERC721 asset when sender has tokenized transfer rights", async function() {
				const atrTokenId = await mint721();

				// Transfer asset from `walletOther` via ATR token
				await atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, false, permission, permissionSignature);

				// Assets owner is `wallet` now
				expect(await t721.ownerOf(tokenId)).to.equal(wallet.address);
			});

			it("Should transfer ERC1155 asset when sender has tokenized transfer rights", async function() {
				const atrTokenId = await mint1155();

				// Transfer asset from `walletOther` via ATR token
				await atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, false, permission, permissionSignature);

				// Assets owner is `wallet` now
				expect(await t1155.balanceOf(wallet.address, tokenId)).to.equal(tokenAmount);
			});

		});

		describe("from contract wallet", function() {

			let ContractWallet, contractWallet;

			before(async function() {
				ContractWallet = await ethers.getContractFactory("ContractWallet");
			});

			beforeEach(async function() {
				contractWallet = await ContractWallet.deploy();

				await wallet.connect(owner).transferOwnership(contractWallet.address);

				permission = [contractWallet.address, wallet.address, nonce];
				permissionSignature = await signPermission(permission, atr.address, owner);
			});


			it("Should transfer ERC20 asset when sender has tokenized transfer rights", async function() {
				const atrTokenId = await mint20();

				// Transfer asset from `walletOther` via ATR token
				await atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, false, permission, permissionSignature);

				// Assets owner is `wallet` now
				expect(await t20.balanceOf(wallet.address)).to.equal(tokenAmount);
			});

			it("Should transfer ERC721 asset when sender has tokenized transfer rights", async function() {
				const atrTokenId = await mint721();

				// Transfer asset from `walletOther` via ATR token
				await atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, false, permission, permissionSignature);

				// Assets owner is `wallet` now
				expect(await t721.ownerOf(tokenId)).to.equal(wallet.address);
			});

			it("Should transfer ERC1155 asset when sender has tokenized transfer rights", async function() {
				const atrTokenId = await mint1155();

				// Transfer asset from `walletOther` via ATR token
				await atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, false, permission, permissionSignature);

				// Assets owner is `wallet` now
				expect(await t1155.balanceOf(wallet.address, tokenId)).to.equal(tokenAmount);
			});

		});

		describe("Without `burnToken` flag", function() {

			it("Should store that recipient has tokenized asset in wallet", async function() {
				const atrTokenId = await mint721();

				// Transfer asset from `walletOther` via ATR token
				await atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, false, permission, permissionSignature);

				// Asset is in `wallet`
				const ids = await atr.ownedAssetATRIds(wallet.address);
				expect(ids.map(bn => bn.toNumber())).to.contain(atrTokenId.toNumber());
			});

			it("Should fail if recipient wallet has approval for asset", async function() {
				const atrTokenId = await mint721();

				// Set operator for asset collection
				await wallet.execute(
					t721.address,
					Iface.ERC721.encodeFunctionData("setApprovalForAll", [owner.address, true])
				);

				// Try to transfer asset from `walletOther` via ATR token
				await expect(
					atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, false, permission, permissionSignature)
				).to.be.revertedWith("Receiver has approvals set for an asset");
			});

			it("Should fail when transferring to other than PWN Wallet", async function() {
				const atrTokenId = await mint721();

				permission = [owner.address, owner.address, nonce];
				permissionSignature = await signPermission(permission, atr.address, owner);

				// Try to transfer asset from `walletOther` via ATR token
				await expect(
					atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, false, permission, permissionSignature)
				).to.be.revertedWith("Attempting to transfer asset to non PWN Wallet address");
			});

		});

		describe("With `burnToken` flag", function() {

			it("Should clear stored tokenized asset data", async function() {
				const atrTokenId = await mint721();

				// Transfer asset from `walletOther` via ATR token
				await atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, true, permission, permissionSignature);

				const asset = await atr.getAsset(2);
				expect(asset.assetAddress).to.equal(ethers.constants.AddressZero);
				expect(asset.category).to.equal(0);
				expect(asset.amount).to.equal(0);
				expect(asset.id).to.equal(0);
			});

			it("Should burn ATR token", async function() {
				const atrTokenId = await mint721();

				// Transfer asset from `walletOther` via ATR token
				await atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, true, permission, permissionSignature);

				await expect(atr.ownerOf(2)).to.be.reverted;
			});

			it("Should transfer asset to any address (not just PWN wallet)", async function() {
				const atrTokenId = await mint721();

				permission = [owner.address, owner.address, nonce];
				permissionSignature = await signPermission(permission, atr.address, owner);

				// Transfer asset from `walletOther` via ATR token
				await atr.connect(addr1).transferAssetWithPermissionFrom(walletOther.address, atrTokenId, true, permission, permissionSignature);

				expect(await t721.ownerOf(tokenId)).to.equal(owner.address);
			});

		});

	});


	describe("Revoke recipient permisison", function() {

		const nonce = ethers.utils.solidityKeccak256([ "string" ], [ "nonce" ]);
		let permission, permissionHash, permissionSignature;

		before(async function() {
			permission = [owner.address, wallet.address, nonce];
			permissionHash = getPermissionHashBytes(permission, atr.address);
			permissionSignature = await signPermission(permission, atr.address, owner);
		});


		it("Should fail when caller didn't sign given permission", async function() {
			await expect(
				atr.connect(other).revokeRecipientPermisison(permissionHash, permissionSignature)
			).to.be.revertedWith("Sender is not a recipient permission signer");
		});

		it("Should fail when permission is already revoked", async function() {
			await atr.revokeRecipientPermisison(permissionHash, permissionSignature);

			await expect(
				atr.revokeRecipientPermisison(permissionHash, permissionSignature)
			).to.be.revertedWith("Recipient permission is revoked");
		});

		it("Should revoke permission", async function() {
			await atr.revokeRecipientPermisison(permissionHash, permissionSignature);

			expect(await atr.revokedPermissions(permissionHash)).to.be.true;
		});

		it("Should emit `RecipientPermissionRevoked` event", async function() {
			await expect(
				atr.revokeRecipientPermisison(permissionHash, permissionSignature)
			).to.emit(atr, "RecipientPermissionRevoked").withArgs(
				ethers.utils.hexValue(permissionHash)
			);
		});

	});


	// Currently cannot be tested.
	// It would require to update `_ownedAssetATRIds` property, but array types are not yet supported by smocks `setVariable` function.
	// See: https://github.com/defi-wonderland/smock/issues/31
	// This function is at least tested through PWNWallet tests
	xdescribe("Check tokenized balance", function() {

		it("Should fail when missing tokenized non-fungible asset");

		it("Should pass when holding tokenized non-fungible asset");

		it("Should fail when insufficient balance of tokenized fungible asset");

		it("Should pass when sufficient balance of tokenized fungible asset");

	});


	describe("Recover invalid tokenized balance", function() {

		const tokenId = 9533;

		beforeEach(async function() {
			await t721.mint(wallet.address, tokenId);

			// Mint ATR token 1
			await wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId]);

			// Create invalid tokenized balance
			await t721.forceTransfer(wallet.address, other.address, tokenId);
		});


		it("Should fail when ATR token is not in callers wallet", async function() {
			await expect(
				atr.recoverInvalidTokenizedBalance(walletOther.address, 1)
			).to.be.revertedWith("Asset is not in callers wallet");
		});

		it("Should fail when tokenized balance is not smaller then actual balance", async function() {
			await t721.mint(wallet.address, 32323);
			await wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, 32323]);

			await expect(
				atr.recoverInvalidTokenizedBalance(wallet.address, 2)
			).to.be.revertedWith("Tokenized balance is not invalid");
		});

		it("Should decrease tokenized balance", async function() {
			await atr.recoverInvalidTokenizedBalance(wallet.address, 1);

			await expect(
				atr.checkTokenizedBalance(wallet.address)
			).to.not.be.reverted;
		});

		it("Should remove ATR token from callers wallet", async function() {
			await atr.recoverInvalidTokenizedBalance(wallet.address, 1);

			const ids = await atr.ownedAssetATRIds(wallet.address);
			expect(ids.map(bn => bn.toNumber())).to.not.include(1);
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
			await wallet.mintAssetTransferRightsToken([t20.address, ERC20, tokenAmount, 0]);
			await wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId]);
			await wallet.mintAssetTransferRightsToken([t1155.address, ERC1155, tokenAmount, tokenId]);

			expect(await areEqual(1, [t20.address, ERC20, tokenAmount, 0])).to.equal(true);
			expect(await areEqual(2, [t721.address, ERC721, 1, tokenId])).to.equal(true);
			expect(await areEqual(3, [t1155.address, ERC1155, tokenAmount, tokenId])).to.equal(true);
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
			await wallet.mintAssetTransferRightsToken([t20.address, ERC20, tokenAmount, 0]);
			await wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, tokenId]);
			await wallet.mintAssetTransferRightsToken([t1155.address, ERC1155, tokenAmount, tokenId]);

			const ids = await atr.ownedAssetATRIds(wallet.address);
			expect(ids.map(bn => bn.toNumber())).to.include.members([1, 2, 3]);
		});

	});


	describe("Owned from collection", function() {

		it("Should return number of tokenized assets from given contract address", async function() {
			await t721.mint(wallet.address, 2);
			await t721.mint(wallet.address, 3);

			await wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, 2]);
			await wallet.mintAssetTransferRightsToken([t721.address, ERC721, 1, 3]);

			const ownedFromERC20Collection = await atr.ownedFromCollection(wallet.address, t20.address);
			expect(ownedFromERC20Collection.toNumber()).to.equal(0);


			let ownedFromERC721Collection = await atr.ownedFromCollection(wallet.address, t721.address);
			expect(ownedFromERC721Collection.toNumber()).to.equal(2);

			await wallet.burnAssetTransferRightsToken(1);
			await wallet.burnAssetTransferRightsToken(2);

			ownedFromERC721Collection = await atr.ownedFromCollection(wallet.address, t721.address);
			expect(ownedFromERC721Collection.toNumber()).to.equal(0);
		});

	});

});
