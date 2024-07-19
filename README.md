# PWN Safe
PWN Safe is a [Safe](https://safe.global/) multisig contract wallet deployed with ATR (Asset Transfer Rights) module and guard. It enables the safe owner to tokenize transfer rights of owned assets and use them in DeFi protocols, most likely as collateral. If an ATR token for an asset is minted, only an ATR token holder can transfer the underlying asset.

The main use case for the PWN Safe is lending without giving up the ownership of the asset. Instead, use assets ATR tokens as collateral. In that case, the utility of the asset is not locked in the lending protocol, waiting until the end of the loan. All airdrops linked to the ownership of assets are still accessible. In case of default, a lender can claim the underlying asset via the ATR token.

PWN Safe is able to hold transfer constraints only if a transaction is initiated by the safe. If the safe grant's approval to another address to transfer the asset, the ATR token is not minted and the asset is not locked.

## How to use
1. Deploy a new safe with the PWN Safe factory
2. Transfer assets to the safe
3. Mint ATR tokens for the assets
4. Use ATR tokens as collateral in DeFi protocols

Safed deployed with PWN Safe factory can be imported into the [official Gnosis Safe UI](https://app.safe.global/). It's recommended to use the official UI for safe management and interaction with DeFi protocols.

## Deployed addresses
<table>
    <tr><th>Name</th><th>Address</th><th>Chain</th></tr>
	<tr>
		<td>Whitelist</td><td>0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e</td><td><a href="https://etherscan.io/address/0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e">Ethereum</a> <a href="https://polygonscan.com/address/0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e">Polygon</a> <a href="https://arbiscan.io/address/0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e">Arbitrum</a> <a href="https://optimistic.etherscan.io/address/0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e">Optimism</a> <a href="https://basescan.org/address/0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e">Base</a> <a href="https://cronoscan.com/address/0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e">Cronos</a> <a href="https://mantlescan.org/address/0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e">Mantle</a> <a href="https://bscscan.com/address/0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e">BSC</a> <a href="https://lineascan.build/address/0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e">Linea</a> <a href="https://goerli.etherscan.io/address/0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e">Goerli</a> <a href="https://sepolia.etherscan.io/address/0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e">Sepolia</a></td>
	</tr>
	<tr>
		<td>FallbackHandler</td><td>0x23456e5a1D93b8C30f75fD60936DC21c0649480D</td><td><a href="https://etherscan.io/address/0x23456e5a1D93b8C30f75fD60936DC21c0649480D">Ethereum</a> <a href="https://polygonscan.com/address/0x23456e5a1D93b8C30f75fD60936DC21c0649480D">Polygon</a> <a href="https://arbiscan.io/address/0x23456e5a1D93b8C30f75fD60936DC21c0649480D">Arbitrum</a> <a href="https://optimistic.etherscan.io/address/0x23456e5a1D93b8C30f75fD60936DC21c0649480D">Optimism</a> <a href="https://basescan.org/address/0x23456e5a1D93b8C30f75fD60936DC21c0649480D">Base</a> <a href="https://cronoscan.com/address/0x23456e5a1D93b8C30f75fD60936DC21c0649480D">Cronos</a> <a href="https://mantlescan.org/address/0x23456e5a1D93b8C30f75fD60936DC21c0649480D">Mantle</a> <a href="https://bscscan.com/address/0x23456e5a1D93b8C30f75fD60936DC21c0649480D">BSC</a> <a href="https://lineascan.build/address/0x23456e5a1D93b8C30f75fD60936DC21c0649480D">Linea</a> <a href="https://goerli.etherscan.io/address/0x23456e5a1D93b8C30f75fD60936DC21c0649480D">Goerli</a> <a href="https://sepolia.etherscan.io/address/0x23456e5a1D93b8C30f75fD60936DC21c0649480D">Sepolia</a></td>
	</tr>
	<tr>
		<td rowspan=2>AssetTransferRights</td><td>0xb20a1745692e8312bd4a2A0092b887526e547F9D</td><td><a href="https://etherscan.io/address/0xb20a1745692e8312bd4a2A0092b887526e547F9D">Ethereum</a> <a href="https://polygonscan.com/address/0xb20a1745692e8312bd4a2A0092b887526e547F9D">Polygon</a> <a href="https://goerli.etherscan.io/address/0xb20a1745692e8312bd4a2A0092b887526e547F9D">Goerli</a></td>
	</tr>
	<tr>
		<td>0x2Af429Ab631Cdd2e9de396F8C838d7ad231E73EB</td><td><a href="https://arbiscan.io/address/0x2Af429Ab631Cdd2e9de396F8C838d7ad231E73EB">Arbitrum</a> <a href="https://optimistic.etherscan.io/address/0x2Af429Ab631Cdd2e9de396F8C838d7ad231E73EB">Optimism</a> <a href="https://basescan.org/address/0x2Af429Ab631Cdd2e9de396F8C838d7ad231E73EB">Base</a> <a href="https://cronoscan.com/address/0x2Af429Ab631Cdd2e9de396F8C838d7ad231E73EB">Cronos</a> <a href="https://mantlescan.org/address/0x2Af429Ab631Cdd2e9de396F8C838d7ad231E73EB">Mantle</a> <a href="https://bscscan.com/address/0x2Af429Ab631Cdd2e9de396F8C838d7ad231E73EB">BSC</a> <a href="https://lineascan.build/address/0x2Af429Ab631Cdd2e9de396F8C838d7ad231E73EB">Linea</a> <a href="https://sepolia.etherscan.io/address/0x2Af429Ab631Cdd2e9de396F8C838d7ad231E73EB">Sepolia</a></td>
	</tr>
	<tr>
		<td rowspan=5>AssetTransferRightsGuard (proxy)</td><td>0xc390f85B5286DBA62C4f1AEC3f451b4267d594DA</td><td><a href="https://etherscan.io/address/0xc390f85B5286DBA62C4f1AEC3f451b4267d594DA">Ethereum</a> <a href="https://polygonscan.com/address/0xc390f85B5286DBA62C4f1AEC3f451b4267d594DA">Polygon</a> <a href="https://goerli.etherscan.io/address/0xc390f85B5286DBA62C4f1AEC3f451b4267d594DA">Goerli</a></td>
	</tr>
	<tr>
		<td>0xd7903fD606C3FfF8d776723Af7CCFB6d6E85B126</td><td><a href="https://arbiscan.io/address/0xd7903fD606C3FfF8d776723Af7CCFB6d6E85B126">Arbitrum</a></td>
	</tr>
	<tr>
		<td>0x7Fef14F22fAC06336097b6C35faCA6359A77eb14</td><td><a href="https://optimistic.etherscan.io/address/0x7Fef14F22fAC06336097b6C35faCA6359A77eb14">Optimism</a> <a href="https://basescan.org/address/0x7Fef14F22fAC06336097b6C35faCA6359A77eb14">Base</a> <a href="https://cronoscan.com/address/0x7Fef14F22fAC06336097b6C35faCA6359A77eb14">Cronos</a> <a href="https://mantlescan.org/address/0x7Fef14F22fAC06336097b6C35faCA6359A77eb14">Mantle</a> <a href="https://sepolia.etherscan.io/address/0x7Fef14F22fAC06336097b6C35faCA6359A77eb14">Sepolia</a></td>
	</tr>
	<tr>
		<td>0x5383C3262d28413bc1372527802DBC35dA69C619</td><td><a href="https://bscscan.com/address/0x5383C3262d28413bc1372527802DBC35dA69C619">BSC</a></td>
	</tr>
	<tr>
		<td>0x2766673305E4543239D27ad187C426e41A6Da8DF</td><td><a href="https://lineascan.build/address/0x2766673305E4543239D27ad187C426e41A6Da8DF">Linea</a></td>
	</tr>
	<tr>
		<td rowspan=5>PWNSafeFactory</td><td>0x408F179dBB365D6601083fb8fF01ff0E1C66AE28</td><td><a href="https://etherscan.io/address/0x408F179dBB365D6601083fb8fF01ff0E1C66AE28">Ethereum</a> <a href="https://polygonscan.com/address/0x408F179dBB365D6601083fb8fF01ff0E1C66AE28">Polygon</a> <a href="https://goerli.etherscan.io/address/0x408F179dBB365D6601083fb8fF01ff0E1C66AE28">Goerli</a></td>
	</tr>
	<tr>
		<td>0x72dc3870FEb5d80f3feC46e3BFDa673170695395</td><td><a href="https://arbiscan.io/address/0x72dc3870FEb5d80f3feC46e3BFDa673170695395">Arbitrum</a></td>
	</tr>
	<tr>
		<td>0xF475aB5843d6688ffFfDAA38e7DEFeAFAc9d9284</td><td><a href="https://optimistic.etherscan.io/address/0xF475aB5843d6688ffFfDAA38e7DEFeAFAc9d9284">Optimism</a> <a href="https://basescan.org/address/0xF475aB5843d6688ffFfDAA38e7DEFeAFAc9d9284">Base</a> <a href="https://cronoscan.com/address/0xF475aB5843d6688ffFfDAA38e7DEFeAFAc9d9284">Cronos</a> <a href="https://mantlescan.org/address/0xF475aB5843d6688ffFfDAA38e7DEFeAFAc9d9284">Mantle</a> <a href="https://sepolia.etherscan.io/address/0xF475aB5843d6688ffFfDAA38e7DEFeAFAc9d9284">Sepolia</a></td>
	</tr>
	<tr>
		<td>0xed53Fdb9018D3EE7051158CB03eD152696F9C8A0</td><td><a href="https://bscscan.com/address/0xed53Fdb9018D3EE7051158CB03eD152696F9C8A0">BSC</a></td>
	</tr>
	<tr>
		<td>0x41Da2f3BDF51dC574Bca114926Df31D521686333</td><td><a href="https://lineascan.build/address/0x41Da2f3BDF51dC574Bca114926Df31D521686333">Linea</a></td>
	</tr>
</table>
