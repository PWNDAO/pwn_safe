# PWNSafe

Collection of guard and module used on top of gnosis safe multisig contract wallet with ability to tokenize assets transfer rights (ATR token). Without transfer rights, wallet owner cannot transfer tokenized assets.

ATR token can be used as a collateral in DeFi protocols as it doesn't make a difference from using the asset itself:
1) borrower cannot move the asset while loan is in progress
2) in case of default, lender can claim ATR token and transfer the asset to his wallet even though he is not the wallet owner

If using ATR token as a collateral instead of an asset, owner of the asset is still the contract wallet which has several interesting consequences:
1) wallet is still an owner of the token so tokens utility is usable
2) all airdrops related to the asset will be collected by the wallet

Assumption for the wallet to work is, that wallet owner cannot grant approval to other address while asset is has its transfer rights minted. In case where "tokenized" asset has some non-standard way how to transfer it / approve it to other address, the wallet cannot provide assurance to the "lender", that the asset is really locked even though ATR token is minted.

## Deployed addresses
| Name | Address | Link |
| --- | --- | --- |
| Whitelist | 0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e | [Polygon](https://polygonscan.com/address/0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e) [Goerli](https://goerli.etherscan.io/address/0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e) [Mumbai](https://mumbai.polygonscan.com/address/0x79EC459C3bA4c64f00353caBF5fa179e059e2e1e)
| FallbackHandler | 0x23456e5a1D93b8C30f75fD60936DC21c0649480D | [Polygon](https://polygonscan.com/address/0x23456e5a1D93b8C30f75fD60936DC21c0649480D) [Goerli](https://goerli.etherscan.io/address/0x23456e5a1D93b8C30f75fD60936DC21c0649480D) [Mumbai](https://mumbai.polygonscan.com/address/0x23456e5a1D93b8C30f75fD60936DC21c0649480D)
| AssetTransferRights | 0xb20a1745692e8312bd4a2A0092b887526e547F9D | [Polygon](https://polygonscan.com/address/0xb20a1745692e8312bd4a2A0092b887526e547F9D) [Goerli](https://goerli.etherscan.io/address/0xb20a1745692e8312bd4a2A0092b887526e547F9D) [Mumbai](https://mumbai.polygonscan.com/address/0xb20a1745692e8312bd4a2A0092b887526e547F9D)
| AssetTransferRightsGuard (proxy) | 0xc390f85B5286DBA62C4f1AEC3f451b4267d594DA | [Polygon](https://polygonscan.com/address/0xc390f85B5286DBA62C4f1AEC3f451b4267d594DA) [Goerli](https://goerli.etherscan.io/address/0xc390f85B5286DBA62C4f1AEC3f451b4267d594DA) [Mumbai](https://mumbai.polygonscan.com/address/0xc390f85B5286DBA62C4f1AEC3f451b4267d594DA)
| PWNSafeFactory | 0x408F179dBB365D6601083fb8fF01ff0E1C66AE28 | [Polygon](https://polygonscan.com/address/0x408F179dBB365D6601083fb8fF01ff0E1C66AE28) [Goerli](https://goerli.etherscan.io/address/0x408F179dBB365D6601083fb8fF01ff0E1C66AE28) [Mumbai](https://mumbai.polygonscan.com/address/0x408F179dBB365D6601083fb8fF01ff0E1C66AE28)
