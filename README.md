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
| Name | Address | Mainnets | Testnets |
| --- | --- | --- | --- |
| Whitelist | 0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e | [Polygon](https://polygonscan.com/address/0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e) | [Goerli](https://goerli.etherscan.io/address/0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e) [Mumbai](https://mumbai.polygonscan.com/address/0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e)
| FallbackHandler | 0x23456e5a1D93b8C30f75fD60936DC21c0649480D | [Polygon](https://polygonscan.com/address/0x23456e5a1D93b8C30f75fD60936DC21c0649480D) | [Goerli](https://goerli.etherscan.io/address/0x23456e5a1D93b8C30f75fD60936DC21c0649480D) [Mumbai](https://mumbai.polygonscan.com/address/0x23456e5a1D93b8C30f75fD60936DC21c0649480D)
| AssetTransferRights | 0xb20a1745692e8312bd4a2A0092b887526e547F9D | [Polygon](https://polygonscan.com/address/0xb20a1745692e8312bd4a2A0092b887526e547F9D) | [Goerli](https://goerli.etherscan.io/address/0xb20a1745692e8312bd4a2A0092b887526e547F9D) [Mumbai](https://mumbai.polygonscan.com/address/0xb20a1745692e8312bd4a2A0092b887526e547F9D)
| AssetTransferRightsGuard (proxy) | 0xc390f85B5286DBA62C4f1AEC3f451b4267d594DA | [Polygon](https://polygonscan.com/address/0xc390f85B5286DBA62C4f1AEC3f451b4267d594DA) | [Goerli](https://goerli.etherscan.io/address/0xc390f85B5286DBA62C4f1AEC3f451b4267d594DA) [Mumbai](https://mumbai.polygonscan.com/address/0xc390f85B5286DBA62C4f1AEC3f451b4267d594DA)
| PWNSafeFactory | 0x408F179dBB365D6601083fb8fF01ff0E1C66AE28 | [Polygon](https://polygonscan.com/address/0x408F179dBB365D6601083fb8fF01ff0E1C66AE28) | [Goerli](https://goerli.etherscan.io/address/0x408F179dBB365D6601083fb8fF01ff0E1C66AE28) [Mumbai](https://mumbai.polygonscan.com/address/0x408F179dBB365D6601083fb8fF01ff0E1C66AE28)
