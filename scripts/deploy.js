const hardhat = require("hardhat");


async function main() {

	console.log("Deploying ATR contract");

	const ATR = await hardhat.ethers.getContractFactory("AssetTransferRights");

	const atr = await ATR.deploy();
	await atr.deployed();

	console.log(`Asset Transfer Rights deploy at: ${atr.address}`);
	console.log(`Wallet deploy at: ${await atr.walletFactory()}`);
}


main()
	.then(() => {
		process.exit(0)})
	.catch(error => {
		console.error(error);
		process.exit(1);
	});
